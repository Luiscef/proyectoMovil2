import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CrearHabitoPage extends StatefulWidget {
  final String? habitoId;
  const CrearHabitoPage({super.key, this.habitoId});

  @override
  State<CrearHabitoPage> createState() => _CrearHabitoPageState();
}

class _CrearHabitoPageState extends State<CrearHabitoPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nombreController = TextEditingController();
  bool completado = false;

  @override
  void initState() {
    super.initState();
    if (widget.habitoId != null) {
      FirebaseFirestore.instance
          .collection('habitos')
          .doc(widget.habitoId)
          .get()
          .then((doc) {
            if (doc.exists) {
              _nombreController.text = doc['nombre'];
              completado = doc['completado'];
              setState(() {});
            }
          });
    }
  }

  void _guardarHabito() {
    if (_formKey.currentState!.validate()) {
      if (widget.habitoId == null) {
        FirebaseFirestore.instance.collection('habitos').add({
          'nombre': _nombreController.text,
          'completado': completado,
        });
      } else {
        FirebaseFirestore.instance
            .collection('habitos')
            .doc(widget.habitoId)
            .update({
              'nombre': _nombreController.text,
              'completado': completado,
            });
      }
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.habitoId == null ? "Crear Hábito" : "Editar Hábito"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nombreController,
                decoration: const InputDecoration(
                  labelText: "Nombre del hábito",
                ),
                validator: (value) =>
                    value!.isEmpty ? "Ingresa un nombre" : null,
              ),
              CheckboxListTile(
                title: const Text("Completado"),
                value: completado,
                onChanged: (value) => setState(() => completado = value!),
              ),
              ElevatedButton(
                onPressed: _guardarHabito,
                child: const Text("Guardar"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
