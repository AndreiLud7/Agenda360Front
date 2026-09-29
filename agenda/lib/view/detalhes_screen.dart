import 'package:flutter/material.dart';

class DetalhesScreen extends StatelessWidget {
  final dynamic consulta;

  const DetalhesScreen({super.key, required this.consulta});

  String _formatarCabecalho() {
    String dataCompleta = consulta['dataHora'] ?? '';
    String local = consulta['local'] ?? 'Local';

    String localFormatado = local.isNotEmpty
        ? local[0].toUpperCase() + local.substring(1).toLowerCase()
        : '';

    if (dataCompleta.length >= 16) {
      String mes = dataCompleta.substring(5, 7);
      String dia = dataCompleta.substring(8, 10);
      String hora = dataCompleta.substring(11, 16);
      return '$localFormatado - $dia/$mes $hora';
    }
    return '$localFormatado - Data inválida';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Detalhes', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text(
                  _formatarCabecalho(),
                  // Fonte aumentada para 26 e com leve negrito
                  style: const TextStyle(fontSize: 26, color: Colors.black87, fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(height: 36),

              // Fontes aumentadas para 20
              Text('Nome: ${consulta['nomePaciente'] ?? ''}', style: const TextStyle(fontSize: 20, color: Colors.black87)),
              const SizedBox(height: 6),
              Text('Tipo: ${consulta['tipo'] ?? ''}', style: const TextStyle(fontSize: 20, color: Colors.black87)),
              const SizedBox(height: 6),
              Text('Telefone: ${consulta['telefonePaciente'] ?? ''}', style: const TextStyle(fontSize: 20, color: Colors.black87)),
              const SizedBox(height: 6),
              Text('Como conheceu: ${consulta['comoConheceu'] ?? ''}', style: const TextStyle(fontSize: 20, color: Colors.black87)),
              const SizedBox(height: 6),
              Text('Valor: R\$ ${(consulta['valor'] ?? 0.0).toStringAsFixed(2).replaceAll('.', ',')}',
                  style: const TextStyle(fontSize: 20, color: Colors.black87)),

              const SizedBox(height: 36),

              // Título do motivo com fonte 20 e leve negrito
              const Text('Motivo do contato:', style: TextStyle(fontSize: 20, color: Colors.black87, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Text(
                consulta['motivoContato']?.isNotEmpty == true
                    ? consulta['motivoContato']
                    : 'Nenhum motivo registrado.',
                // Fonte aumentada para 18
                style: const TextStyle(fontSize: 18, color: Colors.black54, height: 1.5),
              ),

              const Spacer(),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildBotaoAcao('Cancelada', const Color(0xFFDC3545), () {
                  }),
                  _buildBotaoAcao('Editar', const Color(0xFF0D6EFD), () {
                  }),
                  _buildBotaoAcao('Finalizada', Colors.black, () {
                  }),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBotaoAcao(String texto, Color corFundo, VoidCallback acao) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: ElevatedButton(
          onPressed: acao,
          style: ElevatedButton.styleFrom(
            backgroundColor: corFundo,
            padding: const EdgeInsets.symmetric(vertical: 16), // Botão um pouco mais alto para acomodar a fonte maior
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          // Fonte do botão aumentada para 16 e em negrito
          child: Text(texto, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}