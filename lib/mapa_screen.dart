import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapaScreen extends StatefulWidget {
  const MapaScreen({super.key});

  @override
  State<MapaScreen> createState() => _MapaScreenState();
}

// 🔹 Modelo de Veículo
class Veiculo {
  final String nome;
  final String operador;
  final LatLng posicao;

  Veiculo({
    required this.nome,
    required this.operador,
    required this.posicao,
  });
}

class _MapaScreenState extends State<MapaScreen> {
  final MapController _mapController = MapController();

  // 🔹 Lista de veículos (simulação)
  final List<Veiculo> veiculos = [
    Veiculo(
      nome: 'Munck 15t',
      operador: 'João',
      posicao: LatLng(-25.5327, -49.1950),
    ),
    Veiculo(
      nome: 'Guindaste 30t',
      operador: 'Carlos',
      posicao: LatLng(-25.5350, -49.2000),
    ),
    Veiculo(
      nome: 'Munck 20t',
      operador: 'Marcos',
      posicao: LatLng(-25.5300, -49.1900),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Rastreamento de Frota',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF0D1B2A),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FlutterMap(
        mapController: _mapController,
        options: const MapOptions(
          initialCenter: LatLng(-25.5327, -49.1950),
          initialZoom: 13.0,
          interactionOptions: InteractionOptions(
            flags: InteractiveFlag.all,
          ),
        ),
        children: [
          // 🗺️ Camada do mapa (OTIMIZADA)
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.hubdigital.ribas',
            maxZoom: 18,
          ),

          // 📍 Camada de marcadores (OTIMIZADA)
          MarkerLayer(
            markers: veiculos.map((veiculo) {
              return Marker(
                point: veiculo.posicao,
                width: 100,
                height: 60,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.location_on,
                      color: veiculo.nome.contains('Munck')
                          ? const Color(0xFFE87722)
                          : Colors.blue,
                      size: 30,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${veiculo.nome}',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}