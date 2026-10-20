import 'package:flutter/material.dart';
import 'package:agenda/view/editar_consulta.dart';
import 'package:agenda/services/consulta_service.dart'; // Importe o service aqui

class DetalhesScreen extends StatelessWidget {
  final dynamic consulta;
  // Instanciamos o service para poder usar nos botões
  final ConsultaService _consultaService = ConsultaService();

  DetalhesScreen({super.key, required this.consulta});

  String _formatarLocalOuDescricao() {
    String local = consulta['local'] ?? 'Local';
    String descricao = consulta['descricaoLocal'] ?? '';

    // Define qual texto será exibido (Local ou a Descrição se for OUTRO)
    String textoExibicao = (local.toUpperCase() == 'OUTRO' && descricao.isNotEmpty)
        ? descricao
        : local;

    // Formata a primeira letra maiúscula e o resto minúsculo (apenas para cidades)
    if (textoExibicao == local) {
      textoExibicao = textoExibicao.isNotEmpty
          ? textoExibicao[0].toUpperCase() + textoExibicao.substring(1).toLowerCase()
          : '';
    }

    // Limita a 15 caracteres e adiciona "..."
    if (textoExibicao.length > 10) {
      return '${textoExibicao.substring(0, 10)}...';
    }
    return textoExibicao;
  }

  // Retorna a string completa para ser exibida no Tooltip (Hover)
  String _obterLocalCompleto() {
    String local = consulta['local'] ?? 'Local';
    String descricao = consulta['descricaoLocal'] ?? '';
    return (local.toUpperCase() == 'OUTRO' && descricao.isNotEmpty) ? descricao : local;
  }

  String _formatarCabecalho() {
    String dataCompleta = consulta['dataHora'] ?? '';
    String localExibicao = _formatarLocalOuDescricao();

    if (dataCompleta.length >= 16) {
      String mes = dataCompleta.substring(5, 7);
      String dia = dataCompleta.substring(8, 10);
      String hora = dataCompleta.substring(11, 16);
      return '$localExibicao - $dia/$mes $hora';
    }
    return '$localExibicao - Data inválida';
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
                // O Tooltip mostra a string completa quando segurado ou no hover
                child: Tooltip(
                  message: _obterLocalCompleto(),
                  triggerMode: TooltipTriggerMode.tap, // Permite abrir com um clique no celular
                  showDuration: const Duration(seconds: 3), // Tempo que a mensagem fica visível
                  child: Text(
                    _formatarCabecalho(),
                    style: const TextStyle(fontSize: 26, color: Colors.black87, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              const SizedBox(height: 36),

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

              const Text('Motivo do contato:', style: TextStyle(fontSize: 20, color: Colors.black87, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Text(
                consulta['motivoContato']?.isNotEmpty == true
                    ? consulta['motivoContato']
                    : 'Nenhum motivo registrado.',
                style: const TextStyle(fontSize: 18, color: Colors.black54, height: 1.5),
              ),

              const Spacer(),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildBotaoAcao('Cancelada', const Color(0xFFDC3545), () async {
                    final id = consulta['id']; // Pega o ID da consulta
                    if (id != null) {
                      final sucesso = await _consultaService.cancelarConsulta(id);
                      if (sucesso && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Consulta cancelada!'), backgroundColor: Colors.green),
                        );
                        Navigator.pop(context, true); // Volta recarregando a lista
                      } else if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Erro ao cancelar.'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  }),

                  _buildBotaoAcao('Editar', const Color(0xFF0D6EFD), () async {
                    final atualizou = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditarConsulta(consulta: consulta),
                      ),
                    );
                    if (atualizou == true && context.mounted) {
                      Navigator.pop(context, true);
                    }
                  }),

                  _buildBotaoAcao('Finalizada', Colors.black, () async {
                    final id = consulta['id']; // Pega o ID da consulta
                    if (id != null) {
                      final sucesso = await _consultaService.finalizarConsulta(id);
                      if (sucesso && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Consulta finalizada!'), backgroundColor: Colors.green),
                        );
                        Navigator.pop(context, true); // Volta recarregando a lista
                      } else if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Erro ao finalizar.'), backgroundColor: Colors.red),
                        );
                      }
                    }
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
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Text(texto, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}