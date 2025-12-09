const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

// ============ ENVIAR NOTIFICACIÓN DE PRUEBA ============
exports.sendTestNotification = functions.https.onRequest(async (req, res) => {
  const userId = req.query.userId;
  
  if (!userId) {
    res.status(400).send("userId es requerido");
    return;
  }

  try {
    const userDoc = await db.collection("users").doc(userId).get();
    
    if (!userDoc.exists) {
      res.status(404).send("Usuario no encontrado");
      return;
    }

    const fcmToken = userDoc.data().fcmToken;
    
    if (!fcmToken) {
      res.status(400).send("Usuario no tiene token FCM");
      return;
    }

    const message = {
      notification: {
        title: "🎉 ¡Prueba exitosa!",
        body: "Las notificaciones push están funcionando correctamente.",
      },
      token: fcmToken,
    };

    await messaging.send(message);
    res.send("Notificación enviada exitosamente");
  } catch (error) {
    console.error("Error:", error);
    res.status(500).send("Error enviando notificación: " + error.message);
  }
});

// ============ CUANDO SE CREA UN HÁBITO CON RECORDATORIO ============
exports.onHabitCreated = functions.firestore
  .document("users/{userId}/habits/{habitId}")
  .onCreate(async (snap, context) => {
    const habitData = snap.data();
    const userId = context.params.userId;
    const habitId = context.params.habitId;

    // Si tiene recordatorio configurado
    if (habitData.reminderHour !== null && habitData.reminderMinute !== null) {
      console.log(`Nuevo hábito con recordatorio: ${habitData.name}`);
      
      // Guardar información del recordatorio
      await snap.ref.update({
        notificationScheduled: true,
        scheduledTime: `${habitData.reminderHour}:${habitData.reminderMinute}`,
      });
    }

    return null;
  });

// ============ VERIFICAR RECORDATORIOS CADA MINUTO ============
exports.checkHabitReminders = functions.pubsub
  .schedule("every 1 minutes")
  .onRun(async (context) => {
    const now = new Date();
    const currentHour = now.getHours();
    const currentMinute = now.getMinutes();

    console.log(`⏰ Verificando recordatorios: ${currentHour}:${currentMinute}`);

    try {
      // Obtener todos los usuarios
      const usersSnapshot = await db.collection("users").get();

      for (const userDoc of usersSnapshot.docs) {
        const userData = userDoc.data();
        const fcmToken = userData.fcmToken;

        if (!fcmToken) continue;

        // Obtener hábitos del usuario
        const habitsSnapshot = await db
          .collection("users")
          .doc(userDoc.id)
          .collection("habits")
          .get();

        for (const habitDoc of habitsSnapshot.docs) {
          const habit = habitDoc.data();

          if (habit.reminderHour === null || habit.reminderMinute === null) {
            continue;
          }

          // Calcular 5 minutos antes
          let notifHour = habit.reminderHour;
          let notifMinute = habit.reminderMinute - 5;

          if (notifMinute < 0) {
            notifMinute = 60 + notifMinute;
            notifHour = notifHour - 1;
            if (notifHour < 0) notifHour = 23;
          }

          // Verificar si es hora de notificar
          if (currentHour === notifHour && currentMinute === notifMinute) {
            console.log(`📬 Enviando recordatorio: ${habit.name}`);

            const message = {
              notification: {
                title: `⏰ ¡Prepárate!`,
                body: `En 5 minutos: ${habit.name}`,
              },
              data: {
                habitId: habitDoc.id,
                type: "reminder",
              },
              token: fcmToken,
            };

            try {
              await messaging.send(message);
              console.log(`✅ Notificación enviada para: ${habit.name}`);
            } catch (sendError) {
              console.error(`❌ Error enviando a ${habit.name}:`, sendError);
            }
          }
        }
      }
    } catch (error) {
      console.error("Error en checkHabitReminders:", error);
    }

    return null;
  });

// ============ NOTIFICACIÓN DE RACHA ============
exports.onStreakMilestone = functions.firestore
  .document("users/{userId}/habits/{habitId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const userId = context.params.userId;

    // Verificar si la racha cambió
    if (before.streak === after.streak) return null;

    const streak = after.streak;
    const milestones = [7, 14, 21, 30, 60, 90, 100];

    if (!milestones.includes(streak)) return null;

    // Obtener token del usuario
    const userDoc = await db.collection("users").doc(userId).get();
    const fcmToken = userDoc.data()?.fcmToken;

    if (!fcmToken) return null;

    let emoji = "🔥";
    if (streak >= 100) emoji = "💯";
    else if (streak >= 30) emoji = "🏆";
    else if (streak >= 7) emoji = "⭐";

    const message = {
      notification: {
        title: `${emoji} ¡Racha de ${streak} días!`,
        body: `¡Increíble! Llevas ${streak} días seguidos con "${after.name}"`,
      },
      data: {
        habitId: context.params.habitId,
        type: "streak",
      },
      token: fcmToken,
    };

    try {
      await messaging.send(message);
      console.log(`✅ Notificación de racha enviada: ${streak} días`);
    } catch (error) {
      console.error("Error enviando notificación de racha:", error);
    }

    return null;
  });