import 'package:flutter/material.dart';
import 'package:agenda/view/NovaConsulta.dart';
import 'package:agenda/services/consulta_service.dart';
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime _dataSelecionada = DateTime.now();


  final _consultaService = ConsultaService();

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
                  future: _consultaService.buscarConsultas(),
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

                    final listaConsultas = snapshot.data!;

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
        currentIndex: 0, // Destaca a tab "Home"
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.black54,
        showUnselectedLabels: true,
        onTap: (index) {
          if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const NovaConsulta()),
            );
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

    // Extrai apenas a hora "12:00" do formato gigante "2026-04-03T12:00:00"
    String dataCompleta = consulta['dataHora'] ?? '';
    String horario = dataCompleta.length >= 16 ? dataCompleta.substring(11, 16) : '--:--';

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
                '${consulta['nomePaciente']} - ${consulta['tipo']}',
                style: const TextStyle(fontSize: 18, color: Colors.black87),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            ElevatedButton(
              onPressed: () {
                // Ação do botão Detalhes
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