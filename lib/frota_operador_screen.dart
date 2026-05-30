import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'equipamento_detalhes_screen.dart';

class FrotaOperadorScreen extends StatefulWidget {
  const FrotaOperadorScreen({super.key});

  @override
  State<FrotaOperadorScreen> createState() => _FrotaOperadorScreenState();
}

class _FrotaOperadorScreenState extends State<FrotaOperadorScreen> {
  final db = FirebaseFirestore.instance;

  bool carregando = true;
  List<Map<String, dynamic>> equipamentos = [];

  @override
  void initState() {
    super.initState();
    carregarFrotaDoOperador();
  }

  Future<void> carregarFrotaDoOperador() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      setState(() {
        carregando = false;
      });
      return;
    }

    try {
      final snapshot = await db
          .collection('equipamentos')
          .where('operadoresPermitidos', arrayContains: user.uid)
          .get();

      final lista = snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data(),
        };
      }).toList();

      lista.sort((a, b) {
        return (a['nome'] ?? '')
            .toString()
            .toLowerCase()
            .compareTo(
              (b['nome'] ?? '').toString().toLowerCase(),
            );
      });

      setState(() {
        equipamentos = lista;
        carregando = false;
      });
    } catch (e) {
      setState(() {
        carregando = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao carregar frota: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Color statusColor(String status) {
    if (status == 'Manutenção') return const Color(0xFFE87722);
    if (status == 'Inativo') return const Color(0xFFE53935);
    return const Color(0xFF43A047);
  }

  Widget equipamentoCard(Map<String, dynamic> equipamento) {
    final status = equipamento['status'] ?? 'Ativo';
    final cor = statusColor(status);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EquipamentoDetalhesScreen(
              equipamentoId: equipamento['id'],
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: cor.withOpacity(0.15),
              child: Icon(
                Icons.local_shipping_rounded,
                color: cor,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    equipamento['nome'] ?? '',
                    style: const TextStyle(
                      color: Color(0xFF1A202C),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    equipamento['tipo'] ?? 'Sem tipo',
                    style: const TextStyle(
                      color: Color(0xFF718096),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Placa: ${equipamento['placa'] ?? '-'}',
                    style: const TextStyle(
                      color: Color(0xFF718096),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: cor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                status,
                style: TextStyle(
                  color: cor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: const Text(
          'Minha Frota',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF0D1B2A),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: carregando
          ? const Center(child: CircularProgressIndicator())
          : equipamentos.isEmpty
              ? const Center(
                  child: Text(
                    'Nenhum veículo atribuído.',
                    style: TextStyle(
                      color: Color(0xFF718096),
                      fontSize: 15,
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(18),
                  children: equipamentos.map(equipamentoCard).toList(),
                ),
    );
  }
}