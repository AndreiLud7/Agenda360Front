import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:agenda/services/consulta_service.dart';
import 'package:agenda/view/home_screen.dart';
import 'package:agenda/view/agenda_screen.dart';
import 'package:agenda/view/clientes_screen.dart';
import 'package:agenda/view/atestado_screen.dart';

class _DateBrInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final String newText = newValue.text;
    final String oldText = oldValue.text;

    // 1. Se não restaram dígitos, limpa o campo completamente
    if (newText.replaceAll(RegExp(r'[^0-9]'), '').isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    final bool isDeleting = newText.length < oldText.length;

    // 2. Se o campo já estava com a data completa (10 caracteres: DD/MM/AAAA),
    // o cursor estava no final e o usuário digitou um novo número, inicia uma nova data
    if (!isDeleting &&
        oldText.length == 10 &&
        oldValue.selection.isCollapsed &&
        oldValue.selection.end == 10 &&
        newText.length > 10) {
      final String novosDigitos =
          newText.substring(10).replaceAll(RegExp(r'[^0-9]'), '');
      if (novosDigitos.isNotEmpty) {
        return TextEditingValue(
          text: novosDigitos,
          selection: TextSelection.collapsed(offset: novosDigitos.length),
        );
      }
    }

    // 3. Se o usuário pressionou Backspace logo após uma barra '/',
    // apaga o dígito anterior à barra mantendo a estrutura dos segmentos
    if (isDeleting &&
        oldValue.selection.isCollapsed &&
        oldValue.selection.end > 0 &&
        oldText[oldValue.selection.end - 1] == '/') {
      final int slashIndex = oldValue.selection.end - 1;
      final String rightPart = oldText.substring(slashIndex + 1);
      if (rightPart.replaceAll(RegExp(r'[^0-9]'), '').isEmpty) {
        final int cut = math.max(0, slashIndex - 1);
        final String result = oldText.substring(0, cut);
        return TextEditingValue(
          text: result,
          selection: TextSelection.collapsed(offset: result.length),
        );
      } else if (slashIndex > 0) {
        final String result =
            oldText.substring(0, slashIndex - 1) + oldText.substring(slashIndex);
        final int newCursor = slashIndex - 1;
        return TextEditingValue(
          text: result,
          selection: TextSelection.collapsed(offset: newCursor),
        );
      }
    }

    // 4. Edição inteligente por segmentos (dia/mês/ano) quando o campo já possui as 2 barras:
    // evita que apagar ou editar o dia/mês puxe os dígitos do ano ou jogue o cursor para o fim
    final List<String> rawParts = newText.split('/');
    final List<String> oldParts = oldText.split('/');
    if (rawParts.length == 3 && oldParts.length == 3) {
      final int cursor = math.max(0, newValue.selection.end);
      int segIndex = 0;
      int offsetInSeg = cursor;
      int acc = 0;
      for (int i = 0; i < 3; i++) {
        final int segLen = rawParts[i].length;
        if (cursor <= acc + segLen) {
          segIndex = i;
          offsetInSeg = cursor - acc;
          break;
        }
        acc += segLen + 1;
      }

      final List<int> maxLens = [2, 2, 4];
      final List<String> cleanParts = List.generate(3, (i) {
        return rawParts[i].replaceAll(RegExp(r'[^0-9]'), '');
      });

      // Se o usuário apagou o último dígito do ano, remove a barra do ano para continuar apagando
      if (isDeleting && segIndex == 2 && cleanParts[2].isEmpty) {
        final String joined = '${cleanParts[0]}/${cleanParts[1]}';
        return TextEditingValue(
          text: joined,
          selection: TextSelection.collapsed(offset: joined.length),
        );
      }

      bool advanceToNextSeg = false;
      for (int i = 0; i < 3; i++) {
        final int maxLen = maxLens[i];
        if (cleanParts[i].length > maxLen) {
          if (i == segIndex && offsetInSeg <= maxLen) {
            // Sobrescreve o dígito imediatamente à direita do cursor no mesmo segmento
            cleanParts[i] = cleanParts[i].substring(0, offsetInSeg) +
                cleanParts[i].substring(offsetInSeg + 1);
            if (cleanParts[i].length > maxLen) {
              cleanParts[i] = cleanParts[i].substring(0, maxLen);
            }
            if (offsetInSeg == maxLen && i < 2) {
              advanceToNextSeg = true;
            }
          } else if (i == segIndex && offsetInSeg > maxLen && i < 2) {
            // Digitou no final de um segmento já cheio: avança o dígito para o próximo segmento
            final String overflowChar =
                cleanParts[i].substring(maxLen, maxLen + 1);
            cleanParts[i] = cleanParts[i].substring(0, maxLen);
            final int nextMax = maxLens[i + 1];
            if (cleanParts[i + 1].length >= nextMax) {
              cleanParts[i + 1] =
                  overflowChar + cleanParts[i + 1].substring(1);
            } else {
              cleanParts[i + 1] = overflowChar + cleanParts[i + 1];
            }
            segIndex = i + 1;
            offsetInSeg = 1;
          } else {
            cleanParts[i] = cleanParts[i].substring(0, maxLen);
          }
        } else if (!isDeleting &&
            i == segIndex &&
            cleanParts[i].length == maxLen &&
            offsetInSeg == maxLen &&
            i < 2) {
          advanceToNextSeg = true;
        }
      }

      final String rebuilt = cleanParts.join('/');
      int finalCursor = 0;
      for (int i = 0; i < segIndex; i++) {
        finalCursor += cleanParts[i].length + 1;
      }
      finalCursor += math.min(offsetInSeg, cleanParts[segIndex].length);
      if (advanceToNextSeg &&
          finalCursor < rebuilt.length &&
          rebuilt[finalCursor] == '/') {
        finalCursor += 1;
      }

      return TextEditingValue(
        text: rebuilt,
        selection: TextSelection.collapsed(
          offset: math.min(finalCursor, rebuilt.length),
        ),
      );
    }

    // 5. Formatação sequencial padrão (digitação contínua preservando a posição do cursor)
    final String digitsOnly = newText.replaceAll(RegExp(r'[^0-9]'), '');
    final String limited = digitsOnly.length > 8
        ? digitsOnly.substring(0, 8)
        : digitsOnly;

    final int cursorPosition = math.max(0, newValue.selection.end);
    final int digitsBeforeCursor = newText
        .substring(0, math.min(cursorPosition, newText.length))
        .replaceAll(RegExp(r'[^0-9]'), '')
        .length;
    final int targetDigits = math.min(digitsBeforeCursor, limited.length);

    final StringBuffer buffer = StringBuffer();
    int newCursorOffset = 0;
    for (int i = 0; i < limited.length; i++) {
      if (i == 2 || i == 4) {
        buffer.write('/');
        if (i < targetDigits) {
          newCursorOffset++;
        }
      }
      buffer.write(limited[i]);
      if (i < targetDigits) {
        newCursorOffset++;
      }
    }

    final String formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(
        offset: math.min(newCursorOffset, formatted.length),
      ),
    );
  }
}

class FinanceiroScreen extends StatefulWidget {
  const FinanceiroScreen({super.key});

  @override
  State<FinanceiroScreen> createState() => _FinanceiroScreenState();
}

class _FinanceiroScreenState extends State<FinanceiroScreen> {
  final ConsultaService _consultaService = ConsultaService();
  final ScrollController _scrollController = ScrollController();

  late DateTime _dataInicio;
  late DateTime _dataFim;
  late TextEditingController _deController;
  late TextEditingController _ateController;
  final FocusNode _deFocusNode = FocusNode();
  final FocusNode _ateFocusNode = FocusNode();
  bool _deEstavaFocado = false;
  bool _ateEstavaFocado = false;

  bool _isLoading = true;

  List<Map<String, dynamic>> _faturamentoSemanal = [
    {'semana': 'Semana 1', 'valor': 0.0},
    {'semana': 'Semana 2', 'valor': 0.0},
    {'semana': 'Semana 3', 'valor': 0.0},
    {'semana': 'Semana 4', 'valor': 0.0},
  ];
  int _instagramCount = 0;
  int _recomendacaoCount = 0;
  int _facebookCount = 0;
  int _outrosCount = 0;
  List<Map<String, dynamic>> _maioresCausas = [];
  int _procuraramCount = 0;
  int _iniciaramCount = 0;
  int _concluiramCount = 0;

  @override
  void initState() {
    super.initState();
    final DateTime agora = DateTime.now();
    _dataInicio = DateTime(agora.year, agora.month, 1);
    _dataFim = DateTime(agora.year, agora.month + 1, 0);
    _deController = TextEditingController(text: _formatarData(_dataInicio));
    _ateController = TextEditingController(text: _formatarData(_dataFim));

    _deFocusNode.addListener(() {
      if (!_deFocusNode.hasFocus) {
        _deEstavaFocado = false;
      }
    });
    _ateFocusNode.addListener(() {
      if (!_ateFocusNode.hasFocus) {
        _ateEstavaFocado = false;
      }
    });

    _buscarDados(validarCampos: false);
  }

  @override
  void dispose() {
    _deFocusNode.dispose();
    _ateFocusNode.dispose();
    _deController.dispose();
    _ateController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _formatarData(DateTime data) {
    final String dia = data.day.toString().padLeft(2, '0');
    final String mes = data.month.toString().padLeft(2, '0');
    final String ano = data.year.toString().padLeft(4, '0');
    return '$dia/$mes/$ano';
  }

  DateTime? _parseDataBr(String texto) {
    final String limpo = texto.trim();
    final List<String> partes = limpo.split('/');
    if (partes.length != 3) return null;

    final int? dia = int.tryParse(partes[0]);
    final int? mes = int.tryParse(partes[1]);
    final int? ano = int.tryParse(partes[2]);

    if (dia == null || mes == null || ano == null) return null;
    if (ano < 1900 || ano > 2100) return null;
    if (mes < 1 || mes > 12) return null;
    if (dia < 1 || dia > 31) return null;

    final DateTime data = DateTime(ano, mes, dia);
    if (data.year != ano || data.month != mes || data.day != dia) {
      return null;
    }
    return data;
  }

  Future<void> _selecionarDataCalendario({required bool isInicio}) async {
    FocusScope.of(context).unfocus();

    final DateTime? digitada = _parseDataBr(
      isInicio ? _deController.text : _ateController.text,
    );
    final DateTime dataBase = digitada ?? (isInicio ? _dataInicio : _dataFim);
    final DateTime initialDate = dataBase.isBefore(DateTime(2020))
        ? DateTime(2020)
        : (dataBase.isAfter(DateTime(2035, 12, 31))
            ? DateTime(2035, 12, 31)
            : dataBase);

    final DateTime? escolhida = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035, 12, 31),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      helpText: isInicio ? 'Selecionar data inicial (De)' : 'Selecionar data final (Até)',
      cancelText: 'Cancelar',
      confirmText: 'Confirmar',
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

    if (escolhida != null) {
      setState(() {
        if (isInicio) {
          _dataInicio = escolhida;
          _deController.text = _formatarData(escolhida);
        } else {
          _dataFim = escolhida;
          _ateController.text = _formatarData(escolhida);
        }
      });
      await _buscarDados(validarCampos: true);
    }
  }

  void _aoAlterarTextoData(String _) {
    if (_deController.text.trim().length == 10 &&
        _ateController.text.trim().length == 10) {
      final DateTime? inicioParsed = _parseDataBr(_deController.text);
      final DateTime? fimParsed = _parseDataBr(_ateController.text);
      if (inicioParsed != null &&
          fimParsed != null &&
          !inicioParsed.isAfter(fimParsed)) {
        _dataInicio = inicioParsed;
        _dataFim = fimParsed;
        _buscarDados(validarCampos: false);
      }
    }
  }

  Future<void> _buscarDados({bool validarCampos = true}) async {
    if (validarCampos) {
      FocusScope.of(context).unfocus();

      final DateTime? inicioParsed = _parseDataBr(_deController.text);
      final DateTime? fimParsed = _parseDataBr(_ateController.text);

      if (inicioParsed == null || fimParsed == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Por favor, informe datas válidas no formato DD/MM/AAAA.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (inicioParsed.isAfter(fimParsed)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('A data inicial ("De") não pode ser maior que a data final ("Até").'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      _dataInicio = inicioParsed;
      _dataFim = fimParsed;
    }

    setState(() {
      _isLoading = true;
    });

    final DateTime inicio = _dataInicio;
    final DateTime fim = _dataFim;

    final resultados = await Future.wait([
      _consultaService.buscarDadosFinanceiro(
        dataInicio: inicio,
        dataFim: fim,
      ),
      _consultaService.buscarConsultas(),
    ]);

    final Map<String, dynamic>? dadosApi =
        resultados[0] as Map<String, dynamic>?;
    final List<dynamic> todasConsultas =
        (resultados[1] as List<dynamic>?) ?? [];

    if (todasConsultas.isNotEmpty) {
      _calcularDadosLocalmente(todasConsultas, inicio, fim);
    } else if (dadosApi != null) {
      _aplicarDadosBackend(dadosApi);
    } else {
      _calcularDadosLocalmente(const [], inicio, fim);
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _aplicarDadosBackend(Map<String, dynamic> dados) {
    final List<dynamic> listaSemanal = dados['faturamentoSemanal'] ?? [];
    _faturamentoSemanal = listaSemanal.isNotEmpty
        ? listaSemanal.map((item) {
            return {
              'semana': (item['semana'] ?? '').toString(),
              'valor': (item['valor'] as num?)?.toDouble() ?? 0.0,
            };
          }).toList()
        : [
            {'semana': 'Semana 1', 'valor': 0.0},
            {'semana': 'Semana 2', 'valor': 0.0},
            {'semana': 'Semana 3', 'valor': 0.0},
            {'semana': 'Semana 4', 'valor': 0.0},
          ];

    final Map<String, dynamic> origens =
        (dados['origemClientes'] as Map<String, dynamic>?) ?? {};
    _instagramCount = (origens['instagram'] as num?)?.toInt() ?? 0;
    _recomendacaoCount = (origens['recomendacao'] as num?)?.toInt() ?? 0;
    _facebookCount = (origens['facebook'] as num?)?.toInt() ?? 0;
    _outrosCount = (origens['outros'] as num?)?.toInt() ?? 0;

    final List<dynamic> causas = dados['maioresCausas'] ?? [];
    _maioresCausas = causas.map((item) {
      return {
        'causa': (item['causa'] ?? '').toString(),
        'quantidade': (item['quantidade'] as num?)?.toInt() ?? 0,
      };
    }).toList();

    final Map<String, dynamic> conclusao =
        (dados['taxaConclusao'] as Map<String, dynamic>?) ?? {};
    _procuraramCount = (conclusao['procuraram'] as num?)?.toInt() ?? 0;
    _iniciaramCount = (conclusao['iniciaram'] as num?)?.toInt() ?? 0;
    _concluiramCount = (conclusao['concluiram'] as num?)?.toInt() ?? 0;
  }

  void _calcularDadosLocalmente(
    List<dynamic> todasConsultas,
    DateTime inicio,
    DateTime fim,
  ) {
    final DateTime inicioDia = DateTime(inicio.year, inicio.month, inicio.day, 0, 0, 0);
    final DateTime fimDia = DateTime(fim.year, fim.month, fim.day, 23, 59, 59);
    final DateTime inicioData = DateTime(inicio.year, inicio.month, inicio.day);
    final DateTime fimData = DateTime(fim.year, fim.month, fim.day);

    final consultasPeriodo = inicioDia.isAfter(fimDia)
        ? <dynamic>[]
        : todasConsultas.where((c) {
            final String dataStr =
                (c['dataHora'] ?? c['data_hora_consulta'] ?? '').toString();
            final DateTime? dt = DateTime.tryParse(dataStr);
            if (dt == null) return false;
            return !dt.isBefore(inicioDia) && !dt.isAfter(fimDia);
          }).toList();

    final List<double> somas = [0.0, 0.0, 0.0, 0.0];
    final int totalDias = math.max(1, fimData.difference(inicioData).inDays + 1);

    int instagram = 0;
    int recomendacao = 0;
    int facebook = 0;
    int outros = 0;

    final Map<String, int> contagemCausas = {};
    final Map<String, String> rotuloCausas = {};

    int procuraram = consultasPeriodo.length;
    int iniciaram = 0;
    int concluiram = 0;

    for (final c in consultasPeriodo) {
      final String status =
          (c['status'] ?? c['statusConsulta'] ?? '').toString().toUpperCase();
      final bool isFinalizada = status.contains('FINALIZAD');
      final bool isCancelada = status.contains('CANCELAD');

      if (!isCancelada) {
        iniciaram++;
      }
      if (isFinalizada) {
        concluiram++;
        final double valor = (c['valor'] as num?)?.toDouble() ?? 0.0;
        final DateTime? dt = DateTime.tryParse(
          (c['dataHora'] ?? c['data_hora_consulta'] ?? '').toString(),
        );
        if (dt != null) {
          final DateTime dtData = DateTime(dt.year, dt.month, dt.day);
          final int diasDecorridos = math.max(0, dtData.difference(inicioData).inDays);
          final int idx = math.min(3, (diasDecorridos * 4) ~/ totalDias);
          somas[idx] += valor;
        }
      }

      final String origem = (c['comoConheceu'] ?? '').toString().toUpperCase();
      if (origem == 'INSTAGRAM') {
        instagram++;
      } else if (origem == 'RECOMENDACAO') {
        recomendacao++;
      } else if (origem == 'FACEBOOK') {
        facebook++;
      } else {
        outros++;
      }

      final String motivo = (c['motivoContato'] ?? '').toString().trim();
      if (motivo.isNotEmpty) {
        final String chave = motivo.toLowerCase();
        contagemCausas[chave] = (contagemCausas[chave] ?? 0) + 1;
        rotuloCausas.putIfAbsent(
          chave,
          () => motivo[0].toUpperCase() + motivo.substring(1),
        );
      }
    }

    _faturamentoSemanal = List.generate(4, (i) {
      return {
        'semana': 'Semana ${i + 1}',
        'valor': somas[i],
      };
    });

    _instagramCount = instagram;
    _recomendacaoCount = recomendacao;
    _facebookCount = facebook;
    _outrosCount = outros;

    final entradasOrdenadas = contagemCausas.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top4 = entradasOrdenadas.take(4).toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    _maioresCausas = top4.map((e) {
      return {
        'causa': rotuloCausas[e.key] ?? e.key,
        'quantidade': e.value,
      };
    }).toList();

    _procuraramCount = procuraram;
    _iniciaramCount = iniciaram;
    _concluiramCount = concluiram;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.translucent,
          child: Column(
            children: [
              const SizedBox(height: 12),
              // Cabeçalho com botão voltar e título "Financeiro"
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        icon: const Icon(Icons.chevron_left, size: 30, color: Colors.black),
                        onPressed: () {
                          if (Navigator.canPop(context)) {
                            Navigator.pop(context);
                          } else {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (context) => const HomeScreen()),
                            );
                          }
                        },
                      ),
                    ),
                    const Text(
                      'Financeiro',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w400,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Filtro de datas (De / Até / Buscar)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: _buildDateFilterField(
                        label: 'De',
                        controller: _deController,
                        focusNode: _deFocusNode,
                        isInicio: true,
                        onCalendarTap: () => _selecionarDataCalendario(isInicio: true),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildDateFilterField(
                        label: 'Até',
                        controller: _ateController,
                        focusNode: _ateFocusNode,
                        isInicio: false,
                        onCalendarTap: () => _selecionarDataCalendario(isInicio: false),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 44,
                      child: ElevatedButton(
                        onPressed: () => _buscarDados(validarCampos: true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0066CC),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Buscar',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Área rolável com os 4 gráficos
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: Color(0xFF0D6EFD)),
                      )
                    : Scrollbar(
                        controller: _scrollController,
                        thumbVisibility: true,
                        radius: const Radius.circular(8),
                        thickness: 8,
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                          child: Column(
                            children: [
                              _buildFaturamentoCard(),
                              const SizedBox(height: 24),
                              _buildOrigemClientesCard(),
                              const SizedBox(height: 24),
                              _buildMaiorCausaProcuraCard(),
                              const SizedBox(height: 24),
                              _buildTaxaConclusaoCard(),
                            ],
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: 3,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.black54,
        showUnselectedLabels: true,
        onTap: (index) {
          if (index == 0) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const HomeScreen()),
            );
          } else if (index == 1) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const AgendaScreen()),
            );
          } else if (index == 2) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const ClientesScreen()),
            );
          } else if (index == 4) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const AtestadoScreen()),
            );
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

  Widget _buildDateFilterField({
    required String label,
    required TextEditingController controller,
    required FocusNode focusNode,
    required bool isInicio,
    required VoidCallback onCalendarTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 4),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Container(
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE5E5E5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.search,
            inputFormatters: [_DateBrInputFormatter()],
            onTap: () {
              final bool jaEstavaFocado =
                  isInicio ? _deEstavaFocado : _ateEstavaFocado;
              if (!jaEstavaFocado) {
                if (isInicio) {
                  _deEstavaFocado = true;
                } else {
                  _ateEstavaFocado = true;
                }
                Future.delayed(Duration.zero, () {
                  if (mounted && controller.text.isNotEmpty) {
                    controller.selection = TextSelection(
                      baseOffset: 0,
                      extentOffset: controller.text.length,
                    );
                  }
                });
              }
            },
            onChanged: _aoAlterarTextoData,
            onSubmitted: (_) => _buscarDados(validarCampos: true),
            style: const TextStyle(
              fontSize: 13.5,
              color: Colors.black87,
            ),
            decoration: InputDecoration(
              hintText: 'DD/MM/AAAA',
              hintStyle: const TextStyle(fontSize: 12, color: Colors.black38),
              isDense: true,
              contentPadding: const EdgeInsets.only(left: 10, top: 12, bottom: 12),
              border: InputBorder.none,
              suffixIconConstraints: const BoxConstraints(
                minWidth: 32,
                minHeight: 44,
              ),
              suffixIcon: InkWell(
                onTap: onCalendarTap,
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6.0),
                  child: Icon(
                    Icons.calendar_today_outlined,
                    size: 16,
                    color: Colors.black54,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- GRÁFICO 1: FATURAMENTO TOTAL ---
  Widget _buildFaturamentoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        children: [
          const Text(
            'Faturamento total',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3A3A3A),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 170,
            width: double.infinity,
            child: CustomPaint(
              painter: _FaturamentoChartPainter(dados: _faturamentoSemanal),
            ),
          ),
        ],
      ),
    );
  }

  // --- GRÁFICO 2: ORIGEM DOS CLIENTES ---
  Widget _buildOrigemClientesCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              _buildLegendItem(const Color(0xFF7B68EE), 'Instagram'),
              _buildLegendItem(const Color(0xFFFF8A80), 'Recomendação'),
              _buildLegendItem(const Color(0xFF29B6D8), 'Facebook'),
              _buildLegendItem(const Color(0xFFFFA726), 'Outros'),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: SizedBox(
              width: 145,
              height: 145,
              child: CustomPaint(
                painter: _DonutChartPainter(
                  instagram: _instagramCount,
                  recomendacao: _recomendacaoCount,
                  facebook: _facebookCount,
                  outros: _outrosCount,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: EdgeInsets.only(right: 8.0),
              child: Text(
                'Origem dos Clientes',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF3A3A3A),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF555555),
          ),
        ),
      ],
    );
  }

  // --- GRÁFICO 3: MAIOR CAUSA DE PROCURA ---
  Widget _buildMaiorCausaProcuraCard() {
    int maxValor = 15;
    for (final item in _maioresCausas) {
      final int qtd = (item['quantidade'] as int?) ?? 0;
      if (qtd > maxValor) {
        maxValor = ((qtd + 4) ~/ 5) * 5;
      }
    }
    final int step = maxValor ~/ 5;
    final List<int> ticks = List.generate(6, (i) => i * step);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 16, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 8.0),
            child: Text(
              'Maior Causa de Procura',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF3A3A3A),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_maioresCausas.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40.0),
              child: Center(
                child: Text(
                  'Nenhum motivo registrado no período.',
                  style: TextStyle(fontSize: 14, color: Colors.black54),
                ),
              ),
            )
          else
            SizedBox(
              height: 210,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const double labelWidth = 105.0;
                  final double chartWidth =
                      math.max(100.0, constraints.maxWidth - labelWidth - 8.0);

                  return Column(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            // Coluna de rótulos à esquerda
                            SizedBox(
                              width: labelWidth,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: _maioresCausas.map((item) {
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 6.0),
                                  child: Text(
                                      (item['causa'] ?? '').toString(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF555555),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            // Área das barras + grade vertical
                            Expanded(
                              child: Stack(
                                children: [
                                  // Linhas de grade verticais
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: List.generate(6, (index) {
                                      return Container(
                                        width: 1,
                                        height: double.infinity,
                                        color: index == 0
                                            ? const Color(0xFF888888)
                                            : const Color(0xFFE5E5E5),
                                      );
                                    }),
                                  ),
                                  // Barras horizontais
                                  Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: _maioresCausas.map((item) {
                                      final int qtd =
                                          (item['quantidade'] as int?) ?? 0;
                                      final double ratio = maxValor > 0
                                          ? (qtd / maxValor).clamp(0.0, 1.0)
                                          : 0.0;
                                      final double barWidth = math.max(
                                        28.0,
                                        chartWidth * ratio,
                                      );

                                      return Container(
                                        width: barWidth,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: Colors.black,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          qtd.toString(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Eixo X numérico (0, 3, 6, 9, 12, 15)
                      Row(
                        children: [
                          const SizedBox(width: labelWidth),
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: ticks.map((t) {
                                return Text(
                                  t.toString(),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF555555),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  // --- GRÁFICO 4: TAXA DE CONCLUSÃO ---
  Widget _buildTaxaConclusaoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        children: [
          const Text(
            'Taxa de conclusão',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3A3A3A),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            width: double.infinity,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: 8,
                      right: 16,
                      bottom: 24,
                    ),
                    child: CustomPaint(
                      painter: _FunnelChartPainter(
                        procuraram: _procuraramCount,
                        iniciaram: _iniciaramCount,
                        concluiram: _concluiramCount,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 4,
                  bottom: 0,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildFunnelLegendRow(
                        'Procuraram - $_procuraramCount',
                        const Color(0xFF7B68EE),
                      ),
                      const SizedBox(height: 6),
                      _buildFunnelLegendRow(
                        'Iniciaram - $_iniciaramCount',
                        const Color(0xFFFF8A80),
                      ),
                      const SizedBox(height: 6),
                      _buildFunnelLegendRow(
                        'Concluíram - $_concluiramCount',
                        const Color(0xFF29B6D8),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFunnelLegendRow(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF555555),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// PAINTER 1: GRÁFICO DE LINHA / ÁREA (FATURAMENTO TOTAL)
// ============================================================================
class _FaturamentoChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> dados;

  _FaturamentoChartPainter({required this.dados});

  @override
  void paint(Canvas canvas, Size size) {
    const double leftPadding = 42.0;
    const double rightPadding = 18.0;
    const double topPadding = 20.0;
    const double bottomPadding = 26.0;

    final double chartWidth = size.width - leftPadding - rightPadding;
    final double chartHeight = size.height - topPadding - bottomPadding;

    double maxDataVal = 0;
    for (final item in dados) {
      final double v = (item['valor'] as num?)?.toDouble() ?? 0.0;
      if (v > maxDataVal) maxDataVal = v;
    }

    double maxY = 3000.0;
    if (maxDataVal > 3000.0) {
      maxY = ((maxDataVal / 1000.0).ceil() * 1000.0).toDouble();
      if (maxY % 3000 != 0) {
        maxY = ((maxDataVal / 300.0).ceil() * 300.0).toDouble();
      }
    }

    final Paint gridPaint = Paint()
      ..color = const Color(0xFFE5E5E5)
      ..strokeWidth = 1.0;

    final Paint baseLinePaint = Paint()
      ..color = const Color(0xFF888888)
      ..strokeWidth = 1.0;

    // 4 linhas horizontais (0, 1/3, 2/3, maxY)
    for (int i = 0; i <= 3; i++) {
      final double ratio = i / 3.0;
      final double y = topPadding + chartHeight * (1.0 - ratio);
      final double labelValue = (maxY * ratio);

      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(leftPadding + chartWidth, y),
        i == 0 ? baseLinePaint : gridPaint,
      );

      final String yLabel = _formatYAxisNumber(labelValue.round());
      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: yLabel,
          style: const TextStyle(fontSize: 11, color: Color(0xFF666666)),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      tp.paint(
        canvas,
        Offset(leftPadding - tp.width - 6, y - tp.height / 2),
      );
    }

    if (dados.isEmpty) return;

    final int count = dados.length;
    final List<Offset> points = [];

    for (int i = 0; i < count; i++) {
      final double valor = (dados[i]['valor'] as num?)?.toDouble() ?? 0.0;
      final double x = count > 1
          ? leftPadding + (chartWidth * i / (count - 1))
          : leftPadding + chartWidth / 2;
      final double yRatio = maxY > 0 ? (valor / maxY).clamp(0.0, 1.0) : 0.0;
      final double y = topPadding + chartHeight * (1.0 - yRatio);
      points.add(Offset(x, y));

      // Rótulo do eixo X (Semana 1..4)
      final String semanaLabel = (dados[i]['semana'] ?? 'Semana ${i + 1}').toString();
      final TextPainter xTp = TextPainter(
        text: TextSpan(
          text: semanaLabel,
          style: const TextStyle(fontSize: 11, color: Color(0xFF666666)),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      xTp.paint(
        canvas,
        Offset(x - xTp.width / 2, topPadding + chartHeight + 8),
      );
    }

    // Área sombreada cinza sob a linha
    final Path areaPath = Path()
      ..moveTo(points.first.dx, topPadding + chartHeight);
    for (final pt in points) {
      areaPath.lineTo(pt.dx, pt.dy);
    }
    areaPath.lineTo(points.last.dx, topPadding + chartHeight);
    areaPath.close();

    final Paint areaPaint = Paint()
      ..color = const Color(0xFFD6D6D6).withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;
    canvas.drawPath(areaPath, areaPaint);

    // Linha preta conectando os pontos
    final Path linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      linePath.lineTo(points[i].dx, points[i].dy);
    }

    final Paint linePaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawPath(linePath, linePaint);

    // Pontos circulares e rótulos de valor acima de cada ponto
    final Paint dotFillPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final Paint dotStrokePaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < points.length; i++) {
      final Offset pt = points[i];
      canvas.drawCircle(pt, 4.0, dotFillPaint);
      canvas.drawCircle(pt, 4.0, dotStrokePaint);

      final double valor = (dados[i]['valor'] as num?)?.toDouble() ?? 0.0;
      final String valorTexto = valor == valor.roundToDouble()
          ? valor.round().toString()
          : valor.toStringAsFixed(0);

      final TextPainter valTp = TextPainter(
        text: TextSpan(
          text: valorTexto,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF444444),
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      valTp.paint(
        canvas,
        Offset(pt.dx - valTp.width / 2, pt.dy - valTp.height - 6),
      );
    }
  }

  String _formatYAxisNumber(int value) {
    if (value == 0) return '0';
    final String s = value.toString();
    if (s.length <= 3) return s;
    final StringBuffer buffer = StringBuffer();
    int offset = s.length % 3;
    if (offset > 0) {
      buffer.write(s.substring(0, offset));
      if (s.length > offset) buffer.write(',');
    }
    while (offset < s.length) {
      buffer.write(s.substring(offset, offset + 3));
      offset += 3;
      if (offset < s.length) buffer.write(',');
    }
    return buffer.toString();
  }

  @override
  bool shouldRepaint(covariant _FaturamentoChartPainter oldDelegate) {
    return true;
  }
}

// ============================================================================
// PAINTER 2: GRÁFICO DE ROSCA (ORIGEM DOS CLIENTES)
// ============================================================================
class _DonutChartPainter extends CustomPainter {
  final int instagram;
  final int recomendacao;
  final int facebook;
  final int outros;

  _DonutChartPainter({
    required this.instagram,
    required this.recomendacao,
    required this.facebook,
    required this.outros,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final int total = instagram + recomendacao + facebook + outros;
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double outerRadius = math.min(size.width, size.height) / 2;
    final double strokeWidth = outerRadius * 0.46;
    final Rect arcRect = Rect.fromCircle(
      center: center,
      radius: outerRadius - strokeWidth / 2,
    );

    if (total <= 0) {
      final Paint emptyPaint = Paint()
        ..color = const Color(0xFFE0E0E0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;
      canvas.drawArc(arcRect, 0, 2 * math.pi, false, emptyPaint);
      return;
    }

    final List<_SegmentData> segments = [
      _SegmentData(instagram, const Color(0xFF7B68EE)),
      _SegmentData(recomendacao, const Color(0xFFFF8A80)),
      _SegmentData(facebook, const Color(0xFF29B6D8)),
      _SegmentData(outros, const Color(0xFFFFA726)),
    ];

    double startAngle = 0.0;
    for (final seg in segments) {
      if (seg.value <= 0) continue;
      final double sweepAngle = (seg.value / total) * 2 * math.pi;
      final Paint segPaint = Paint()
        ..color = seg.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;

      canvas.drawArc(arcRect, startAngle, sweepAngle, false, segPaint);
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return true;
  }
}

class _SegmentData {
  final int value;
  final Color color;
  _SegmentData(this.value, this.color);
}

// ============================================================================
// PAINTER 4: GRÁFICO DE FUNIL HORIZONTAL (TAXA DE CONCLUSÃO)
// ============================================================================
class _FunnelChartPainter extends CustomPainter {
  final int procuraram;
  final int iniciaram;
  final int concluiram;

  _FunnelChartPainter({
    required this.procuraram,
    required this.iniciaram,
    required this.concluiram,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double centerY = h / 2;

    final double x0 = 0;
    final double x1 = w / 3;
    final double x2 = (w * 2) / 3;
    final double x3 = w;

    if (procuraram <= 0) {
      // Estado vazio: desenha o funil em tom neutro cinza claro
      final double halfH0 = (h * 0.92) / 2;
      final double halfH1 = (h * 0.48) / 2;
      final double halfH2 = (h * 0.36) / 2;

      final Path emptyFunnel = Path()
        ..moveTo(x0, centerY - halfH0)
        ..lineTo(x1, centerY - halfH1)
        ..lineTo(x2, centerY - halfH2)
        ..lineTo(x3, centerY)
        ..lineTo(x2, centerY + halfH2)
        ..lineTo(x1, centerY + halfH1)
        ..lineTo(x0, centerY + halfH0)
        ..close();

      canvas.drawPath(
        emptyFunnel,
        Paint()
          ..color = const Color(0xFFE5E5E5)
          ..style = PaintingStyle.fill,
      );

      final Paint dividerPaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 1.5;
      canvas.drawLine(
        Offset(x1, centerY - halfH1),
        Offset(x1, centerY + halfH1),
        dividerPaint,
      );
      canvas.drawLine(
        Offset(x2, centerY - halfH2),
        Offset(x2, centerY + halfH2),
        dividerPaint,
      );
      return;
    }

    // Alturas proporcionais aos valores filtrados
    const double r1 = 0.92;
    final double r2 = iniciaram > 0
        ? (iniciaram / procuraram).clamp(0.24, 0.72) * r1
        : 0.14 * r1;
    final double r3 = concluiram > 0
        ? (concluiram / procuraram).clamp(0.16, r2 * 0.85) * r1
        : 0.08 * r1;

    final double halfH0 = (h * r1) / 2;
    final double halfH1 = (h * r2) / 2;
    final double halfH2 = (h * r3) / 2;

    // Estágio 1: Roxo (Procuraram)
    final Path stage1 = Path()
      ..moveTo(x0, centerY - halfH0)
      ..lineTo(x1, centerY - halfH1)
      ..lineTo(x1, centerY + halfH1)
      ..lineTo(x0, centerY + halfH0)
      ..close();

    canvas.drawPath(
      stage1,
      Paint()
        ..color = const Color(0xFF7B68EE)
        ..style = PaintingStyle.fill,
    );

    // Estágio 2: Salmão (Iniciaram)
    final Path stage2 = Path()
      ..moveTo(x1, centerY - halfH1)
      ..lineTo(x2, centerY - halfH2)
      ..lineTo(x2, centerY + halfH2)
      ..lineTo(x1, centerY + halfH1)
      ..close();

    canvas.drawPath(
      stage2,
      Paint()
        ..color = iniciaram > 0 ? const Color(0xFFFF8A80) : const Color(0xFFE5E5E5)
        ..style = PaintingStyle.fill,
    );

    // Estágio 3: Ciano (Concluíram)
    final Path stage3 = Path()
      ..moveTo(x2, centerY - halfH2)
      ..lineTo(x3, centerY)
      ..lineTo(x2, centerY + halfH2)
      ..close();

    canvas.drawPath(
      stage3,
      Paint()
        ..color = concluiram > 0 ? const Color(0xFF29B6D8) : const Color(0xFFE5E5E5)
        ..style = PaintingStyle.fill,
    );

    // Linhas divisórias brancas entre os estágios
    final Paint dividerPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.5;

    canvas.drawLine(
      Offset(x1, centerY - halfH1),
      Offset(x1, centerY + halfH1),
      dividerPaint,
    );
    canvas.drawLine(
      Offset(x2, centerY - halfH2),
      Offset(x2, centerY + halfH2),
      dividerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _FunnelChartPainter oldDelegate) {
    return true;
  }
}
