import 'package:flutter/material.dart';
import 'package:agenda/services/consulta_service.dart';

class EditarConsulta extends StatefulWidget {
  // Recebe os dados da consulta que veio da tela de Detalhes
  final Map<String, dynamic> consulta;

  const EditarConsulta({super.key, required this.consulta});

  @override
  State<EditarConsulta> createState() => _EditarConsultaState();
}

class _EditarConsultaState extends State<EditarConsulta> {
  late TextEditingController _nomeController;
  late TextEditingController _telefoneController;
  late TextEditingController _localController;
  late TextEditingController _horarioController;
  late TextEditingController _valorController;
  late TextEditingController _motivoController;

  final ConsultaService _consultaService = ConsultaService();
  bool _isSaving = false;

  late String _comoConheceu;
  late String _tipo;
  late String _dataOriginal; // Para manter a mesma data ao atualizar

  @override
  void initState() {
    super.initState();
    // Inicializa os campos com os dados que vieram da consulta
    _nomeController = TextEditingController(text: widget.consulta['nomePaciente'] ?? '');
    _telefoneController = TextEditingController(text: widget.consulta['telefonePaciente'] ?? '');
    _localController = TextEditingController(text: widget.consulta['local'] ?? '');
    _motivoController = TextEditingController(text: widget.consulta['motivoContato'] ?? '');

    // Trata o Horário e a Data
    _dataOriginal = widget.consulta['dataHora'] ?? '';
    String horario = '12:00';
    if (_dataOriginal.contains('T')) {
      horario = _dataOriginal.split('T')[1].substring(0, 5); // Pega apenas HH:mm
    }
    _horarioController = TextEditingController(text: horario);

    // Trata o Valor (converte de double para String com vírgula)
    double valor = widget.consulta['valor'] ?? 0.0;
    _valorController = TextEditingController(text: valor.toStringAsFixed(2).replaceAll('.', ','));

    // Trata os Enums da API (converte de UPPERCASE para o formato visualizado na tela)
    _comoConheceu = _formatarEnumParaUI(widget.consulta['comoConheceu'] ?? 'INSTAGRAM');
    _tipo = _formatarEnumParaUI(widget.consulta['tipo'] ?? 'CONSULTA');
  }

  // Função auxiliar para arrumar o nome na AppBar ("João Silva - 03/04")
  String _gerarTituloAppBar() {
    String nome = widget.consulta['nomePaciente'] ?? 'Editar';
    String primeiroNome = nome.split(' ')[0];
    String dataFormatada = '';

    if (_dataOriginal.contains('T')) {
      try {
        DateTime dt = DateTime.parse(_dataOriginal);
        String dia = dt.day.toString().padLeft(2, '0');
        String mes = dt.month.toString().padLeft(2, '0');
        dataFormatada = ' - $dia/$mes';
      } catch (e) {
        dataFormatada = '';
      }
    }
    return '$primeiroNome$dataFormatada';
  }

  // Auxiliares para converter Enums entre UI e API
  String _formatarEnumParaUI(String valorAPI) {
    if (valorAPI == 'RECOMENDACAO') return 'Recomendação';
    if (valorAPI.isEmpty) return 'Outros';
    return valorAPI[0].toUpperCase() + valorAPI.substring(1).toLowerCase();
  }

  String _formatarUIParaEnum(String valorUI) {
    if (valorUI == 'Recomendação') return 'RECOMENDACAO';
    return valorUI.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _gerarTituloAppBar(),
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTextField('Nome Completo', _nomeController),
            const SizedBox(height: 16),
            _buildTextField('Telefone', _telefoneController),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildRadioGroup(
                    'Como conheceu',
                    ['Facebook', 'Instagram', 'Recomendação', 'Outros'],
                    _comoConheceu,
                        (val) => setState(() => _comoConheceu = val.toString()),
                  ),
                ),
                Expanded(
                  child: _buildRadioGroup(
                    'Tipo',
                    ['Consulta', 'Terapia', 'Retorno'],
                    _tipo,
                        (val) => setState(() => _tipo = val.toString()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildTextField('Local', _localController)),
                const SizedBox(width: 16),
                Expanded(child: _buildTextField('Horário', _horarioController)),
              ],
            ),
            const SizedBox(height: 16),
            _buildTextField('Valor', _valorController),
            const SizedBox(height: 16),
            _buildTextField('Motivo do contato', _motivoController, maxLines: 3),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerRight,
              child: _isSaving
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                onPressed: () async {
                  setState(() { _isSaving = true; });

                  String horario = _horarioController.text.trim();
                  if (horario.isEmpty) horario = "12:00";

                  // Reconstrói a data com o horário novo modificado
                  String dataBase = _dataOriginal.contains('T')
                      ? _dataOriginal.split('T')[0]
                      : DateTime.now().toIso8601String().substring(0, 10);

                  final dadosAtualizados = {
                    // Note que substituí os valores chumbados pela escolha real do usuário
                    'nomePaciente': _nomeController.text,
                    'telefonePaciente': _telefoneController.text,
                    'comoConheceu': _formatarUIParaEnum(_comoConheceu),
                    'tipo': _formatarUIParaEnum(_tipo),
                    'local': _localController.text.toUpperCase(),
                    'descricaoLocal': widget.consulta['descricaoLocal'] ?? '',
                    'dataHora': '${dataBase}T$horario:00',
                    'valor': double.tryParse(_valorController.text.replaceAll(',', '.')) ?? 0.0,
                    'motivoContato': _motivoController.text,
                    'status': widget.consulta['status'], // mantém o status atual
                  };

                  final idConsulta = widget.consulta['id']; // Pega o ID (UUID) que vem da API

                  final sucesso = await _consultaService.editarConsulta(idConsulta, dadosAtualizados);

                  setState(() { _isSaving = false; });

                  if (sucesso) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Consulta atualizada com sucesso!'), backgroundColor: Colors.green),
                    );
                    Navigator.pop(context, true); // Retorna true para a tela anterior atualizar a lista
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Erro ao atualizar.'), backgroundColor: Colors.red),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D6EFD),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Salvar', style: TextStyle(fontSize: 16, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Widgets _buildTextField e _buildRadioGroup iguais aos do seu NovaConsulta ---
  Widget _buildTextField(String label, TextEditingController controller, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF0D6EFD)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRadioGroup(String title, List<String> options, String groupValue, ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 4),
        ...options.map((option) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Radio<String>(
              value: option,
              groupValue: groupValue,
              onChanged: onChanged,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              activeColor: Colors.black,
            ),
            Text(option, style: const TextStyle(fontSize: 14)),
          ],
        )).toList(),
      ],
    );
  }
}