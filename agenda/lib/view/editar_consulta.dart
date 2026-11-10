import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:agenda/services/consulta_service.dart';

// --- FORMATADOR DE MOEDA (DE TRÁS PARA FRENTE) ---
class MoneyInputFormatter extends TextInputFormatter {
  final NumberFormat _formatter = NumberFormat.currency(locale: 'pt_BR', symbol: '');

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue.copyWith(text: '');

    String numbersOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (numbersOnly.isEmpty) return newValue.copyWith(text: '');

    // Limita a 10 dígitos (99.999.999,99) para respeitar precision=10, scale=2 do banco MySQL
    if (numbersOnly.length > 10) {
      numbersOnly = numbersOnly.substring(0, 10);
    }

    double value = double.parse(numbersOnly) / 100;
    String newText = _formatter.format(value).trim();

    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}

class EditarConsulta extends StatefulWidget {
  final Map<String, dynamic> consulta;
  const EditarConsulta({super.key, required this.consulta});

  @override
  State<EditarConsulta> createState() => _EditarConsultaState();
}

class _EditarConsultaState extends State<EditarConsulta> {
  late TextEditingController _nomeController;
  late TextEditingController _descricaoLocalController;
  late TextEditingController _dataController;
  late TextEditingController _horarioController;
  late TextEditingController _valorController;
  late TextEditingController _motivoController;
  late TextEditingController _telefoneController;
  final _scrollController = ScrollController();

  final ConsultaService _consultaService = ConsultaService();
  bool _isSaving = false;

  late String _comoConheceu;
  late String _tipo;
  late String _local;
  late String _dataOriginal;
  late DateTime _dataSelecionada;

  // --- MÁSCARA DE TELEFONE ---
  final _telefoneMask = MaskTextInputFormatter(
    mask: '+55 (##) #####-####',
    filter: {"#": RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );

  @override
  void initState() {
    super.initState();
    _nomeController = TextEditingController(text: widget.consulta['nomePaciente'] ?? '');
    _motivoController = TextEditingController(text: widget.consulta['motivoContato'] ?? '');
    _descricaoLocalController = TextEditingController(text: widget.consulta['descricaoLocal'] ?? '');

    String tel = widget.consulta['telefonePaciente'] ?? '';
    _telefoneController = TextEditingController(text: tel);

    _dataOriginal = widget.consulta['dataHora'] ?? '';
    _dataSelecionada = DateTime.tryParse(_dataOriginal) ?? DateTime.now();
    _dataController = TextEditingController(
      text:
          '${_dataSelecionada.day.toString().padLeft(2, '0')}/${_dataSelecionada.month.toString().padLeft(2, '0')}/${_dataSelecionada.year}',
    );

    String horario = '12:00';
    if (_dataOriginal.contains('T')) {
      horario = _dataOriginal.split('T')[1].substring(0, 5);
    }
    _horarioController = TextEditingController(text: horario);

    double valorNumerico = (widget.consulta['valor'] as num?)?.toDouble() ?? 0.0;
    String valorInicial = NumberFormat.currency(locale: 'pt_BR', symbol: '').format(valorNumerico).trim();
    _valorController = TextEditingController(text: valorInicial);

    _comoConheceu = _formatarEnumParaUI(widget.consulta['comoConheceu'] ?? 'INSTAGRAM');
    _tipo = _formatarEnumParaUI(widget.consulta['tipo'] ?? 'CONSULTA');

    String localSalvo = widget.consulta['local'] ?? 'GASPAR';
    _local = _formatarEnumParaUI(localSalvo);
    if (!['Gaspar', 'Blumenau', 'Outro'].contains(_local)) {
      _local = 'Outro';
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _descricaoLocalController.dispose();
    _dataController.dispose();
    _horarioController.dispose();
    _valorController.dispose();
    _motivoController.dispose();
    _telefoneController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _selecionarData() async {
    final hoje = DateTime.now();
    final primeiroDia = DateTime(hoje.year, hoje.month, hoje.day);
    final dataInicial = _dataSelecionada.isBefore(primeiroDia) ? primeiroDia : _dataSelecionada;

    final DateTime? novaData = await showDatePicker(
      context: context,
      initialDate: dataInicial,
      firstDate: primeiroDia,
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

    if (novaData != null) {
      setState(() {
        _dataSelecionada = novaData;
        _dataController.text =
            '${novaData.day.toString().padLeft(2, '0')}/${novaData.month.toString().padLeft(2, '0')}/${novaData.year}';
      });
    }
  }

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

  String _gerarTituloAppBar() {
    String nome = widget.consulta['nomePaciente'] ?? 'Editar';
    String primeiroNome = nome.split(' ')[0];
    String dia = _dataSelecionada.day.toString().padLeft(2, '0');
    String mes = _dataSelecionada.month.toString().padLeft(2, '0');
    return '$primeiroNome - $dia/$mes';
  }

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
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scrollbar(
          controller: _scrollController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTextField('Nome Completo', _nomeController, maxLength: 70),
                const SizedBox(height: 12),
                _buildTextField(
                    'Telefone',
                    _telefoneController,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [_telefoneMask],
                    hintText: '+55 (00) 00000-0000'
                ),
                const SizedBox(height: 12),
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
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildDatePickerField()),
                    const SizedBox(width: 16),
                    Expanded(child: _buildTimePickerField()),
                  ],
                ),
                const SizedBox(height: 12),
                _buildDropdownLocal(),
                if (_local == 'Outro') ...[
                  const SizedBox(height: 12),
                  _buildTextField('Descrição do Local (Ex: Clínica no Centro)', _descricaoLocalController, maxLength: 100),
                ],
                const SizedBox(height: 12),
                _buildTextField(
                    'Valor (R\$)',
                    _valorController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [MoneyInputFormatter()],
                    hintText: '0,00'
                ),
                const SizedBox(height: 12),
                _buildTextField('Motivo do contato', _motivoController, maxLines: 2, maxLength: 300),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: _isSaving
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                    onPressed: () async {
                      // --- VALIDAÇÃO 0: NOME ---
                      if (_nomeController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Por favor, informe o nome do paciente.'), backgroundColor: Colors.red),
                        );
                        return;
                      }

                      // --- VALIDAÇÃO 1: LOCAL ---
                      if (_local == 'Outro' && _descricaoLocalController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Por favor, informe a descrição do local.'), backgroundColor: Colors.red),
                        );
                        return;
                      }

                      // --- VALIDAÇÃO 2: TELEFONE ---
                      String telNumeros = _telefoneController.text.replaceAll(RegExp(r'[^0-9]'), '');
                      // Verifica se tem algo além do '55' (DDI do Brasil)
                      if (telNumeros.isNotEmpty && telNumeros != '55') {
                        // 55 + DDD(2) + Num(8 ou 9) = 12 ou 13
                        if (telNumeros.length != 12 && telNumeros.length != 13) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Telefone inválido. Preencha corretamente ou deixe vazio.'), backgroundColor: Colors.red),
                          );
                          return;
                        }
                      }

                      String horario = _horarioController.text.trim();
                      if (horario.isEmpty) horario = "12:00";

                      String dataBase =
                          '${_dataSelecionada.year}-${_dataSelecionada.month.toString().padLeft(2, '0')}-${_dataSelecionada.day.toString().padLeft(2, '0')}';

                      final dataHoraEscolhida = DateTime.tryParse('${dataBase}T$horario:00');

                      // --- VALIDAÇÃO 3: HORÁRIO NO PASSADO ---
                      if (dataHoraEscolhida != null && dataHoraEscolhida.isBefore(DateTime.now())) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Não é possível agendar uma consulta em um horário que já passou.'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      setState(() { _isSaving = true; });

                      final idConsulta = widget.consulta['id'];

                      // --- VALIDAÇÃO 4: CONFLITO DE DIA E HORÁRIO ---
                      if (dataHoraEscolhida != null) {
                        final todasConsultas = await _consultaService.buscarConsultas();
                        final bool temConflito = todasConsultas.any((c) {
                          if (c['id']?.toString() == idConsulta?.toString()) return false;

                          final String status = (c['status'] ?? '').toString().toUpperCase();
                          final bool estaAtiva = status.contains('MARCAD');
                          if (!estaAtiva) return false;

                          final String dataStr = (c['dataHora'] ?? '').toString();
                          final DateTime? dt = DateTime.tryParse(dataStr);
                          if (dt == null) return false;

                          return dt.year == dataHoraEscolhida.year &&
                              dt.month == dataHoraEscolhida.month &&
                              dt.day == dataHoraEscolhida.day &&
                              dt.hour == dataHoraEscolhida.hour &&
                              dt.minute == dataHoraEscolhida.minute;
                        });

                        if (temConflito) {
                          setState(() { _isSaving = false; });
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Já existe outra consulta marcada para este dia às $horario.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                      }

                      double valorNumerico = 0.0;
                      if (_valorController.text.isNotEmpty) {
                        String valorLimpo = _valorController.text.replaceAll('.', '').replaceAll(',', '.');
                        valorNumerico = double.tryParse(valorLimpo) ?? 0.0;
                      }

                      final dadosAtualizados = {
                        'nomePaciente': _nomeController.text,
                        'telefonePaciente': _telefoneController.text.trim().isEmpty || _telefoneController.text == '+55 ' ? '' : _telefoneController.text,
                        'comoConheceu': _formatarUIParaEnum(_comoConheceu),
                        'tipo': _formatarUIParaEnum(_tipo),
                        'local': _formatarUIParaEnum(_local),
                        'descricaoLocal': _local == 'Outro' ? _descricaoLocalController.text : '',
                        'dataHora': '${dataBase}T$horario:00',
                        'valor': valorNumerico,
                        'motivoContato': _motivoController.text,
                        'status': widget.consulta['status'],
                      };

                      final sucesso = await _consultaService.editarConsulta(idConsulta, dadosAtualizados);

                      setState(() { _isSaving = false; });

                      if (sucesso) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Consulta atualizada com sucesso!'), backgroundColor: Colors.green),
                        );
                        Navigator.pop(context, true);
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
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {int maxLines = 1, int? maxLength, TextInputType keyboardType = TextInputType.text, List<TextInputFormatter>? inputFormatters, String? hintText}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            if (maxLength != null)
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, value, _) {
                  return Text(
                    '${value.text.length}/$maxLength',
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                  );
                },
              ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          maxLength: maxLength,
          scrollPhysics: maxLines > 1 ? const NeverScrollableScrollPhysics() : null,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          decoration: InputDecoration(
            counterText: '',
            hintText: hintText,
            hintStyle: const TextStyle(color: Colors.black38),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
              visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
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
        const SizedBox(height: 6),
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

  Widget _buildDatePickerField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Data', style: TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 6),
        TextField(
          controller: _dataController,
          readOnly: true,
          onTap: _selecionarData,
          style: const TextStyle(fontSize: 15),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            suffixIcon: const Icon(Icons.calendar_today, color: Colors.grey, size: 18),
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

  Widget _buildTimePickerField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Horário', style: TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 6),
        TextField(
          controller: _horarioController,
          readOnly: true,
          onTap: _selecionarHorario,
          style: const TextStyle(fontSize: 15),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
