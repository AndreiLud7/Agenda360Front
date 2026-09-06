import 'package:flutter/material.dart';
import 'package:agenda/view/NovaConsulta.dart';
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime _dataSelecionada = DateTime.now();

  // Dados simulados. Futuramente, sua API Java retornará uma lista parecida com esta
  // baseada na _dataSelecionada.
  final List<Map<String, dynamic>> _consultasDoDia = [
    {'horario': '14:00', 'nome': 'João Silva', 'tipo': 'Consulta'},
    {'horario': '15:30', 'nome': 'Bernado', 'tipo': 'Terapia'},
  ];

  // Função para abrir o calendário e filtrar o dia
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
              primary: Color(0xFF0D6EFD), // Cor azul do seu app no calendário
            ),
          ),
          child: child!,
        );
      },
    );

    if (dataEscolhida != null && dataEscolhida != _dataSelecionada) {
      setState(() {
        _dataSelecionada = dataEscolhida;
        // FUTURO: Aqui você chamará o ConsultaService para buscar os dados do novo dia
        // ex: carregarConsultas(dataEscolhida);
      });
    }
  }

  // Formatação simples para exibir "Sexta - 03/04" sem precisar de pacotes extras
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
              // Cabeçalho com o Filtro de Data
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
              // Lista de Consultas do Dia
              Expanded(
                child: ListView.separated(
                  itemCount: _consultasDoDia.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 32),
                  itemBuilder: (context, index) {
                    final consulta = _consultasDoDia[index];
                    return _buildCardConsulta(consulta);
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
          if (index == 1) { // O índice 1 corresponde ao segundo ícone ("Consultas")
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

  // Componente visual de cada item da lista
  Widget _buildCardConsulta(Map<String, dynamic> consulta) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          consulta['horario'],
          style: const TextStyle(fontSize: 32, color: Colors.black),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                '${consulta['nome']} - ${consulta['tipo']}',
                style: const TextStyle(fontSize: 18, color: Colors.black87),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            ElevatedButton(
              onPressed: () {
                // Ação para abrir detalhes do paciente
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D6EFD), // Azul
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