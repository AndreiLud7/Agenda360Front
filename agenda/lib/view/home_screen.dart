import 'package:flutter/material.dart';
import 'package:agenda/view/NovaConsulta.dart';
import 'package:agenda/services/consulta_service.dart';
import 'package:agenda/view/detalhes_screen.dart';
import 'package:agenda/view/agenda_screen.dart';
import 'package:agenda/view/atestado_screen.dart';
import 'clientes_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime _dataSelecionada = DateTime.now();
  final _consultaService = ConsultaService();

  late Future<List<dynamic>> _futureConsultas;

  @override
  void initState() {
    super.initState();
    _carregarConsultas();
  }

  void _carregarConsultas() {
    setState(() {
      _futureConsultas = _consultaService.buscarConsultas();
    });
  }

  Future<void> _escolherData(BuildContext context) async {
    final DateTime? dataEscolhida = await showDatePicker(
      context: context,
      initialDate: _dataSelecionada,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0D6EFD),
            ),
          ),
          child: child!,
        );
      },
    );

    if (dataEscolhida != null && dataEscolhida != _dataSelecionada) {
      setState(() {
        _dataSelecionada = dataEscolhida;
      });
    }
  }

  String _formatarDataVisor(DateTime data) {
    const List<String> diasSemana = ['Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado', 'Domingo'];
    String diaNome = diasSemana[data.weekday - 1];
    String dia = data.day.toString().padLeft(2, '0');
    String mes = data.month.toString().padLeft(2, '0');
    return '$diaNome - $dia/$mes';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              Center(
                child: InkWell(
                  onTap: () => _escolherData(context),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatarDataVisor(_dataSelecionada),
                          style: const TextStyle(
                            fontSize: 28,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.keyboard_arrow_down, color: Colors.black54),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              Expanded(
                child: FutureBuilder<List<dynamic>>(
                  future: _futureConsultas,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Color(0xFF0D6EFD)));
                    }

                    if (snapshot.hasError) {
                      return Center(child: Text('Erro: ${snapshot.error}'));
                    }

                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(child: Text('Nenhuma consulta agendada.', style: TextStyle(fontSize: 18, color: Colors.black54)));
                    }

                    // --- FILTRAGEM E ORDENAÇÃO POR HORÁRIO ---
                    final todasConsultas = snapshot.data!;
                    final listaConsultas = todasConsultas.where((consulta) {
                      String dataHoraStr = consulta['dataHora'] ?? '';
                      String status = (consulta['status'] ?? '').toString().toUpperCase();

                      bool ehMarcada = status.contains('MARCADA') || status.contains('MARCADO');

                      if (dataHoraStr.length >= 10 && ehMarcada) {
                        try {
                          DateTime dataConsulta = DateTime.parse(dataHoraStr);
                          return dataConsulta.year == _dataSelecionada.year &&
                              dataConsulta.month == _dataSelecionada.month &&
                              dataConsulta.day == _dataSelecionada.day;
                        } catch (e) {
                          return false;
                        }
                      }
                      return false;
                    }).toList();

                    // Ordena a lista do horário mais cedo para o mais tarde (crescente)
                    listaConsultas.sort((a, b) {
                      String dataA = a['dataHora'] ?? '';
                      String dataB = b['dataHora'] ?? '';
                      return dataA.compareTo(dataB);
                    });

                    if (listaConsultas.isEmpty) {
                      return const Center(
                        child: Text(
                          'Nenhuma consulta ativa para este dia.',
                          style: TextStyle(fontSize: 18, color: Colors.black54),
                        ),
                      );
                    }

                    return ListView.separated(
                      itemCount: listaConsultas.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 32),
                      itemBuilder: (context, index) {
                        final consulta = listaConsultas[index];
                        return _buildCardConsulta(consulta);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: 0,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.black54,
        showUnselectedLabels: true,
        onTap: (index) async {
          if (index == 1) {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const AgendaScreen()));
          } else if (index == 2) {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const ClientesScreen()));
          } else if (index == 4) {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const AtestadoScreen()));
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today_outlined), label: 'Consultas'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Clientes'),
          BottomNavigationBarItem(icon: Icon(Icons.attach_money), label: 'Financeiro'),
          BottomNavigationBarItem(icon: Icon(Icons.menu_book_outlined), label: 'Atestado'),
        ],
      ),
    );
  }

  Widget _buildCardConsulta(dynamic consulta) {
    String dataCompleta = consulta['dataHora'] ?? '';
    String horario = '--:--';
    if (dataCompleta.contains('T')) {
      horario = dataCompleta.split('T')[1].substring(0, 5);
    } else if (dataCompleta.length >= 16) {
      horario = dataCompleta.substring(11, 16);
    }

    String nome = consulta['nomePaciente'] ?? '';
    String tipo = consulta['tipo'] ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          horario,
          style: const TextStyle(fontSize: 32, color: Colors.black),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                '$nome - $tipo',
                style: const TextStyle(fontSize: 18, color: Colors.black87),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final resultado = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DetalhesScreen(consulta: consulta),
                  ),
                );

                if (resultado == true) {
                  _carregarConsultas();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D6EFD),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Detalhes', style: TextStyle(fontSize: 14)),
            ),
          ],
        ),
      ],
    );
  }
}