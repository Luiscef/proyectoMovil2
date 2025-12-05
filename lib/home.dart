import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'editarhabit.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Mis Hábitos")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('habitos').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());

          final habitos = snapshot.data!.docs;

          return ListView.builder(
            itemCount: habitos.length,
            itemBuilder: (context, index) {
              var habito = habitos[index];
              return ListTile(
                title: Text(habito['nombre']),
                trailing: Checkbox(
                  value: habito['completado'],
                  onChanged: (value) {
                    FirebaseFirestore.instance
                        .collection('habitos')
                        .doc(habito.id)
                        .update({'completado': value});
                  },
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CrearHabitoPage(habitoId: habito.id),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CrearHabitoPage()),
          );
        },
      ),
    );
  }
}
