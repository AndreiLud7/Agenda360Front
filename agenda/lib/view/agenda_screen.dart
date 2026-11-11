import 'package:flutter/material.dart';
import 'package:agenda/view/NovaConsulta.dart'; // Ajuste o caminho se precisar
import 'package:agenda/view/home_screen.dart';
import 'package:agenda/view/clientes_screen.dart';
import 'package:agenda/view/atestado_screen.dart';
import 'package:agenda/view/financeiro_screen.dart';

class AgendaScreen extends StatefulWidget {
  const AgendaScreen({super.key});

  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  DateTime _dataSelecionada = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final hoje = DateTime.now();
    final primeiroDiaPermitido = DateTime(hoje.year, hoje.month, hoje.day);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Agenda', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Escolha a melhor data para a sua consulta',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),

          // O Calendário Nativo do Flutter
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: CalendarDatePicker(
              initialDate: _dataSelecionada.isBefore(primeiroDiaPermitido)
                  ? primeiroDiaPermitido
                  : _dataSelecionada,
              firstDate: primeiroDiaPermitido, // Não deixa marcar no passado
              lastDate: DateTime(2030),
              onDateChanged: (DateTime novaData) {
                setState(() {
                  _dataSelecionada = novaData;
                });
              },
            ),
          ),

          const Spacer(),

          // Botão azul que envia a data para a próxima tela
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // Aqui acontece a mágica: enviamos a variável para a NovaConsulta
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NovaConsulta(dataEscolhida: _dataSelecionada),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D6EFD), // Azul
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Marcar consulta', style: TextStyle(color: Colors.white, fontSize: 18)),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: 1,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.black54,
        showUnselectedLabels: true,
        onTap: (index) {
          if (index == 0) {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomeScreen()));
          } else if (index == 2) {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const ClientesScreen()));
          } else if (index == 3) {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const FinanceiroScreen()));
          } else if (index == 4) {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const AtestadoScreen()));
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
}
