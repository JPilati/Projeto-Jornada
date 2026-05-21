import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class MapaScreen extends StatefulWidget {
  const MapaScreen({super.key});

  @override
  State<MapaScreen> createState() => _MapaScreenState();
}

class DestinoCliente {
  final String nome;
  final String endereco;
  final LatLng local;

  const DestinoCliente({
    required this.nome,
    required this.endereco,
    required this.local,
  });
}

class _MapaScreenState extends State<MapaScreen> {
  final MapController mapController = MapController();
  final TextEditingController destinoController = TextEditingController();

  LatLng origem = const LatLng(-25.4297, -49.2719);
  LatLng? destino;
  List<LatLng> rotaReal = [];

    double distanciaKm = 0;
    double duracaoMin = 0;

  bool carregandoLocalizacao = false;
  String origemTexto = 'Curitiba - PR';

  final List<DestinoCliente> clientes = const [
    DestinoCliente(
      nome: 'Cliente Centro',
      endereco: 'Centro, Curitiba - PR',
      local: LatLng(-25.4284, -49.2733),
    ),
    DestinoCliente(
      nome: 'Cliente São José dos Pinhais',
      endereco: 'São José dos Pinhais - PR',
      local: LatLng(-25.5327, -49.1950),
    ),
    DestinoCliente(
      nome: 'Cliente Pinhais',
      endereco: 'Pinhais - PR',
      local: LatLng(-25.4446, -49.1928),
    ),
    DestinoCliente(
      nome: 'Cliente Araucária',
      endereco: 'Araucária - PR',
      local: LatLng(-25.5936, -49.4103),
    ),
  ];

  @override
  void initState() {
    super.initState();
    buscarLocalizacaoAtual();
  }

  @override
  void dispose() {
    destinoController.dispose();
    super.dispose();
  }
  Future<void> buscarRotaReal(LatLng destinoFinal) async {
    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${origem.longitude},${origem.latitude};'
        '${destinoFinal.longitude},${destinoFinal.latitude}'
        '?overview=full&geometries=geojson',
      );

      final response = await http.get(url);

      if (response.statusCode != 200) {
        throw Exception('Erro ao buscar rota');
      }

      final data = jsonDecode(response.body);

      final route = data['routes'][0];

      final geometry = route['geometry']['coordinates'] as List;

      final distance = route['distance'];
      final duration = route['duration'];

      final pontos = geometry.map((coord) {
        return LatLng(coord[1], coord[0]);
      }).toList();

      setState(() {
        rotaReal = pontos;
        distanciaKm = distance / 1000;
        duracaoMin = duration / 60;
      });
    } catch (e) {
      mostrarMensagem('Erro ao calcular rota.');
    }
  }

  Future<void> buscarLocalizacaoAtual() async {
    setState(() {
      carregandoLocalizacao = true;
    });

    try {
      final servicoAtivo = await Geolocator.isLocationServiceEnabled();

      if (!servicoAtivo) {
        throw Exception('Localização desativada.');
      }

      LocationPermission permissao = await Geolocator.checkPermission();

      if (permissao == LocationPermission.denied) {
        permissao = await Geolocator.requestPermission();
      }

      if (permissao == LocationPermission.denied ||
          permissao == LocationPermission.deniedForever) {
        throw Exception('Permissão negada.');
      }

      await Future.delayed(const Duration(seconds: 1));

      final posicao = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 0,
        ),
      );

      setState(() {
        origem = LatLng(posicao.latitude, posicao.longitude);
        origemTexto = 'Localização atual';
      });

      mapController.move(origem, 15);
    } catch (_) {
      setState(() {
        origem = const LatLng(-25.4297, -49.2719);
        origemTexto = 'Curitiba - PR';
      });

      mapController.move(origem, 13);

      mostrarMensagem(
        'Não foi possível obter sua localização. Usando Curitiba como origem.',
      );
    } finally {
      if (mounted) {
        setState(() {
          carregandoLocalizacao = false;
        });
      }
    }
  }

  void selecionarDestino(DestinoCliente cliente) async {
    setState(() {
      destino = cliente.local;
      destinoController.text = cliente.nome;
    });

    await buscarRotaReal(cliente.local);

    final centro = LatLng(
      (origem.latitude + cliente.local.latitude) / 2,
      (origem.longitude + cliente.local.longitude) / 2,
    );

    mapController.move(centro, 11.5);
  }

  void limparDestino() {
    setState(() {
      destino = null;
      rotaReal = [];
      distanciaKm = 0;
      duracaoMin = 0;
      destinoController.clear();
    });

    mapController.move(origem, 14);
  }

  void mostrarMensagem(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem)),
    );
  }

  List<Marker> get marcadores {
    return [
      Marker(
        point: origem,
        width: 70,
        height: 70,
        child: const Icon(
          Icons.my_location_rounded,
          color: Color(0xFF0D47A1),
          size: 36,
        ),
      ),
      if (destino != null)
        Marker(
          point: destino!,
          width: 70,
          height: 70,
          child: const Icon(
            Icons.location_on_rounded,
            color: Color(0xFFE53935),
            size: 42,
          ),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: const Text(
          'Mapa de Rota',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF0D1B2A),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: origem,
              initialZoom: 13,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://cartodb-basemaps-a.global.ssl.fastly.net/light_all/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.hubdigital.ribas',
                maxZoom: 19,
              ),
              if (rotaReal.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: rotaReal,
                      strokeWidth: 5,
                      color: const Color(0xFF0D47A1),
                    ),
                  ],
                ),
              MarkerLayer(markers: marcadores),
            ],
          ),

          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.16),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.radio_button_checked,
                        color: Color(0xFF0D47A1),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          origemTexto,
                          style: const TextStyle(
                            color: Color(0xFF1A202C),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (carregandoLocalizacao)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: destinoController,
                    readOnly: true,
                    decoration: InputDecoration(
                      hintText: 'Selecionar destino',
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: Color(0xFF718096),
                      ),
                      suffixIcon: destino == null
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: limparDestino,
                            ),
                      filled: true,
                      fillColor: const Color(0xFFF4F7FB),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onTap: abrirListaDestinos,
                  ),
                  if (rotaReal.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF4F7FB),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  'Distância',
                                  style: TextStyle(
                                    color: Color(0xFF718096),
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${distanciaKm.toStringAsFixed(1)} km',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF4F7FB),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  'Tempo',
                                  style: TextStyle(
                                    color: Color(0xFF718096),
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${duracaoMin.toStringAsFixed(0)} min',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          Positioned(
            right: 16,
            bottom: 24,
            child: Column(
              children: [
                FloatingActionButton(
                  heroTag: 'location',
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF0D47A1),
                  onPressed: buscarLocalizacaoAtual,
                  child: const Icon(Icons.my_location_rounded),
                ),
                const SizedBox(height: 12),
                if (destino != null)
                  FloatingActionButton(
                    heroTag: 'route',
                    backgroundColor: const Color(0xFF0D47A1),
                    foregroundColor: Colors.white,
                    onPressed: () {
                      mapController.move(destino!, 14);
                    },
                    child: const Icon(Icons.flag_rounded),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void abrirListaDestinos() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFD0D7E2),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 18),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Selecionar destino',
                  style: TextStyle(
                    color: Color(0xFF1A202C),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              ...clientes.map((cliente) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE8F0FD),
                    child: Icon(
                      Icons.location_on_rounded,
                      color: Color(0xFF0D47A1),
                    ),
                  ),
                  title: Text(
                    cliente.nome,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(cliente.endereco),
                  onTap: () {
                    Navigator.pop(context);
                    selecionarDestino(cliente);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }
}