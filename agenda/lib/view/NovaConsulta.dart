import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:agenda/view/home_screen.dart';
import 'package:agenda/services/consulta_service.dart';

// --- FORMATADOR DE MOEDA (DE TRÁS PARA FRENTE) ---
class MoneyInputFormatter extends TextInputFormatter {
  final NumberFormat _formatter = NumberFormat.currency(locale: 'pt_BR', symbol: '');

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue.copyWith(text: '');

    String numbersOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (numbersOnly.isEmpty) return newValue.copyWith(text: '');

    double value = double.parse(numbersOnly) / 100;
    String newText = _formatter.format(value).trim();

    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}

class NovaConsulta extends StatefulWidget {
  final DateTime dataEscolhida;
  const NovaConsulta({super.key, required this.dataEscolhida});

  @override
  State<NovaConsulta> createState() => _NovaConsultaState();
}

class _NovaConsultaState extends State<NovaConsulta> {
  final _nomeController = TextEditingController();
  final _descricaoLocalController = TextEditingController();
  final _horarioController = TextEditingController(text: '12:00');
  final _valorController = TextEditingController();
  final _motivoController = TextEditingController();

  final _telefoneController = TextEditingController();

  final ConsultaService _consultaService = ConsultaService();
  bool _isSaving = false;

  String _comoConheceu = 'Instagram';
  String _tipo = 'Terapia';
  String _local = 'Gaspar';

  // --- MÁSCARA DE TELEFONE ---
  final _telefoneMask = MaskTextInputFormatter(
    mask: '+55 (##) #####-####',
    filter: {"#": RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );

  Future<void> _selecionarHorario() async {
    final List<String> partes = _horarioController.text.split(':');
    final TimeOfDay horarioAtual = TimeOfDay(
      hour: int.tryParse(partes[0]) ?? 12,
      minute: int.tryParse(partes[1]) ?? 0,
    );

    final TimeOfDay? selecionado = await showTimePicker(
      context: context,
      initialTime: horarioAtual,
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );

    if (selecionado != null) {
      setState(() {
        final String horaFormatada = selecionado.hour.toString().padLeft(2, '0');
        final String minutoFormatado = selecionado.minute.toString().padLeft(2, '0');
        _horarioController.text = '$horaFormatada:$minutoFormatado';
      });
    }
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
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text(
          'Nova consulta - ${widget.dataEscolhida.day.toString().padLeft(2, '0')}/${widget.dataEscolhida.month.toString().padLeft(2, '0')}',
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
            _buildTextField(
                'Telefone',
                _telefoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [_telefoneMask],
                hintText: '+55 (00) 00000-0000'
            ),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildDropdownLocal()),
                const SizedBox(width: 16),
                Expanded(child: _buildTimePickerField()),
              ],
            ),
            if (_local == 'Outro') ...[
              const SizedBox(height: 16),
              _buildTextField('Descrição do Local (Ex: Clínica no Centro)', _descricaoLocalController),
            ],
            const SizedBox(height: 16),
            _buildTextField(
                'Valor (R\$)',
                _valorController,
                keyboardType: TextInputType.number,
                inputFormatters: [MoneyInputFormatter()],
                hintText: '0,00'
            ),
            const SizedBox(height: 16),
            _buildTextField('Motivo do contato', _motivoController, maxLines: 3),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerRight,
              child: _isSaving
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                onPressed: () async {
                  // --- VALIDAÇÃO 1: LOCAL ---
                  if (_local == 'Outro' && _descricaoLocalController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Por favor, informe a descrição do local.'), backgroundColor: Colors.red),
                    );
                    return;
                  }

                  // --- VALIDAÇÃO 2: TELEFONE ---
                  String telNumeros = _telefoneController.text.replaceAll(RegExp(r'[^0-9]'), '');
                  if (telNumeros.isNotEmpty && telNumeros != '55') {
                    if (telNumeros.length != 12 && telNumeros.length != 13) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Telefone inválido. Preencha corretamente ou deixe vazio.'), backgroundColor: Colors.red),
                      );
                      return;
                    }
                  }

                  setState(() { _isSaving = true; });
                  String horario = _horarioController.text.trim();
                  if (horario.isEmpty) horario = "12:00";

                  String statusInicial;
                  if (_tipo == 'Consulta') {
                    statusInicial = 'CONSULTA_MARCADA';
                  } else if (_tipo == 'Terapia') {
                    statusInicial = 'TERAPIA_MARCADA';
                  } else {
                    statusInicial = 'RETORNO_MARCADO';
                  }

                  double valorNumerico = 0.0;
                  if (_valorController.text.isNotEmpty) {
                    String valorLimpo = _valorController.text.replaceAll('.', '').replaceAll(',', '.');
                    valorNumerico = double.tryParse(valorLimpo) ?? 0.0;
                  }

                  final dados = {
                    'nomePaciente': _nomeController.text,
                    'telefonePaciente': _telefoneController.text.trim().isEmpty || _telefoneController.text == '+55 ' ? '' : _telefoneController.text,
                    'comoConheceu': _comoConheceu.toUpperCase(),
                    'tipo': _tipo.toUpperCase(),
                    'local': _local.toUpperCase(),
                    'descricaoLocal': _local == 'Outro' ? _descricaoLocalController.text : '',
                    'dataHora': '${widget.dataEscolhida.toIso8601String().substring(0, 10)}T$horario:00',
                    'valor': valorNumerico,
                    'motivoContato': _motivoController.text,
                    'status': statusInicial,
                  };

                  final sucesso = await _consultaService.salvarConsulta(dados);
                  setState(() { _isSaving = false; });

                  if (sucesso) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Salvo com sucesso!'), backgroundColor: Colors.green),
                    );
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => const HomeScreen()),
                          (Route<dynamic> route) => false,
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Erro ao salvar.'), backgroundColor: Colors.red),
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
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.black54,
        showUnselectedLabels: true,
        onTap: (index) {
          if (index == 0) {
            Navigator.pop(context);
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today_outlined), label: 'Consultas'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Clientes'),
          BottomNavigationBarItem(icon: Icon(Icons.attach_money), label: 'Financeiro'),
          BottomNavigationBarItem(icon: Icon(Icons.menu_book_outlined), label: 'Atestado'),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {int maxLines = 1, TextInputType keyboardType = TextInputType.text, List<TextInputFormatter>? inputFormatters, String? hintText}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(color: Colors.black38),
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

  Widget _buildDropdownLocal() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Local', style: TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE0E0E0)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _local,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
              items: ['Gaspar', 'Blumenau', 'Outro'].map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value, style: const TextStyle(fontSize: 15)),
                );
              }).toList(),
              onChanged: (newValue) {
                if (newValue != null) {
                  setState(() {
                    _local = newValue;
                    if (_local != 'Outro') {
                      _descricaoLocalController.clear();
                    }
                  });
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimePickerField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Horário', style: TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 8),
        TextField(
          controller: _horarioController,
          readOnly: true,
          onTap: _selecionarHorario,
          style: const TextStyle(fontSize: 15),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            suffixIcon: const Icon(Icons.access_time, color: Colors.grey, size: 20),
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
}