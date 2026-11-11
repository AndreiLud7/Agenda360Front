import 'package:flutter/material.dart';
import 'package:agenda/services/consulta_service.dart';
import 'package:agenda/view/home_screen.dart';
import 'package:agenda/view/agenda_screen.dart';
import 'package:agenda/view/atestado_screen.dart';
import 'package:agenda/view/detalhes_screen.dart';
import 'package:agenda/view/financeiro_screen.dart';

class ClientesScreen extends StatefulWidget {
  const ClientesScreen({super.key});

  @override
  State<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends State<ClientesScreen> {
  final _consultaService = ConsultaService();
  late Future<List<dynamic>> _clientesFuture;

  // Variáveis para guardar o que o usuário quer filtrar
  String _nomeBusca = '';
  String _tipoFiltro = 'Todos';
  String _statusFiltro = 'Todos'; // Novo filtro de status
  int? _diaFiltro; // null = Todos
  int? _mesFiltro; // null = Todos
  int? _anoFiltro; // null = Todos

  static const List<String> _nomesMeses = [
    'Janeiro',
    'Fevereiro',
    'Março',
    'Abril',
    'Maio',
    'Junho',
    'Julho',
    'Agosto',
    'Setembro',
    'Outubro',
    'Novembro',
    'Dezembro',
  ];

  // Controlador para ler o que for digitado no campo de texto
  final TextEditingController _buscaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _carregarClientes();
  }

  void _carregarClientes() {
    setState(() {
      _clientesFuture = _consultaService.buscarConsultas();
    });
  }

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  // Deixa o status bonitinho
  String _formatarStatus(String statusCru) {
    if (statusCru.isEmpty) return '';
    String texto = statusCru.replaceAll('_', ' ').toLowerCase();
    return texto[0].toUpperCase() + texto.substring(1);
  }

  // Formata a data e hora da consulta (ex: 21/10/2026 às 14:30)
  String _formatarDataHora(String dataHoraCru) {
    if (dataHoraCru.isEmpty) return 'Sem data';
    try {
      DateTime data = DateTime.parse(dataHoraCru);
      String dia = data.day.toString().padLeft(2, '0');
      String mes = data.month.toString().padLeft(2, '0');
      String ano = data.year.toString();
      String hora = data.hour.toString().padLeft(2, '0');
      String minuto = data.minute.toString().padLeft(2, '0');
      return '$dia/$mes/$ano às $hora:$minuto';
    } catch (e) {
      return dataHoraCru;
    }
  }

  // Define a cor baseada no status
  Color _corDoStatus(String statusCru) {
    String status = statusCru.toUpperCase();
    if (status.contains('CANCELADA') || status.contains('CANCELADO')) {
      return Colors.red;
    } else if (status.contains('MARCADA') || status.contains('MARCADO')) {
      return const Color(0xFF0D6EFD); // Azul
    }
    return Colors.black54; // Cor padrão para finalizados ou outros
  }

  // Lógica de filtro atualizada: verifica Nome, Tipo, Status e Data (Dia, Mês, Ano) ao mesmo tempo
  List<dynamic> _filtrarLista(List<dynamic> todosClientes) {
    return todosClientes.where((cliente) {
      String nome = (cliente['nomePaciente'] ?? '').toString().toLowerCase();
      String tipo = (cliente['tipo'] ?? '').toString().toUpperCase();
      String status = (cliente['status'] ?? '').toString().toUpperCase();
      String dataHoraStr = (cliente['dataHora'] ?? cliente['data_hora_consulta'] ?? '').toString();

      // Regra 1: O nome digitado está contido no nome do paciente?
      bool passaNome = _nomeBusca.isEmpty || nome.contains(_nomeBusca.toLowerCase());

      // Regra 2: O tipo selecionado bate com o tipo?
      bool passaTipo = _tipoFiltro == 'Todos' || tipo == _tipoFiltro.toUpperCase();

      // Regra 3: O status selecionado bate com o status? (Suporta masculino/feminino, ex: RETORNO_MARCADO e CONSULTA_MARCADA)
      bool passaStatus = true;
      if (_statusFiltro != 'Todos') {
        String prefixoStatus = _statusFiltro.toUpperCase();
        if (prefixoStatus.endsWith('A')) {
          prefixoStatus = prefixoStatus.substring(0, prefixoStatus.length - 1);
        }
        passaStatus = status.contains(prefixoStatus);
      }

      // Regra 4: A data da consulta bate com o Dia, Mês e Ano selecionados?
      bool passaData = true;
      if (_diaFiltro != null || _mesFiltro != null || _anoFiltro != null) {
        DateTime? dataConsulta = DateTime.tryParse(dataHoraStr);
        if (dataConsulta == null) {
          passaData = false;
        } else {
          bool passaDia = _diaFiltro == null || dataConsulta.day == _diaFiltro;
          bool passaMes = _mesFiltro == null || dataConsulta.month == _mesFiltro;
          bool passaAno = _anoFiltro == null || dataConsulta.year == _anoFiltro;
          passaData = passaDia && passaMes && passaAno;
        }
      }

      // Só mostra na tela se passar em todas as regras
      return passaNome && passaTipo && passaStatus && passaData;
    }).toList();
  }

  // Desenha a aba que sobe de baixo para cima com os filtros
  void _mostrarModalFiltros() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Filtrar Clientes',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        TextButton(
                          onPressed: () {
                            setStateModal(() {
                              _buscaController.clear();
                              _nomeBusca = '';
                              _tipoFiltro = 'Todos';
                              _statusFiltro = 'Todos';
                              _diaFiltro = null;
                              _mesFiltro = null;
                              _anoFiltro = null;
                            });
                            setState(() {});
                          },
                          child: const Text(
                            'Limpar filtros',
                            style: TextStyle(color: Color(0xFF0D6EFD)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 1. Filtro por Nome (Campo de digitação)
                    TextField(
                      controller: _buscaController,
                      decoration: InputDecoration(
                        labelText: 'Buscar por nome...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onChanged: (valor) {
                        setState(() {
                          _nomeBusca = valor;
                        });
                      },
                    ),
                    const SizedBox(height: 24),

                    // 2. Filtro por Data (Dia, Mês e Ano)
                    const Text(
                      'Data da Consulta:',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        // Seletor de Dia
                        Expanded(
                          flex: 2,
                          child: _buildDropdownData(
                            label: 'Dia',
                            valorAtual: _diaFiltro,
                            itens: [
                              const DropdownMenuItem<int?>(
                                value: null,
                                child: Text('Todos'),
                              ),
                              ...List.generate(31, (index) {
                                final dia = index + 1;
                                return DropdownMenuItem<int?>(
                                  value: dia,
                                  child: Text(dia.toString().padLeft(2, '0')),
                                );
                              }),
                            ],
                            onChanged: (novoDia) {
                              setStateModal(() => _diaFiltro = novoDia);
                              setState(() => _diaFiltro = novoDia);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Seletor de Mês
                        Expanded(
                          flex: 3,
                          child: _buildDropdownData(
                            label: 'Mês',
                            valorAtual: _mesFiltro,
                            itens: [
                              const DropdownMenuItem<int?>(
                                value: null,
                                child: Text('Todos'),
                              ),
                              ...List.generate(12, (index) {
                                final mes = index + 1;
                                return DropdownMenuItem<int?>(
                                  value: mes,
                                  child: Text(
                                    _nomesMeses[index],
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }),
                            ],
                            onChanged: (novoMes) {
                              setStateModal(() => _mesFiltro = novoMes);
                              setState(() => _mesFiltro = novoMes);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Seletor de Ano
                        Expanded(
                          flex: 2,
                          child: _buildDropdownData(
                            label: 'Ano',
                            valorAtual: _anoFiltro,
                            itens: [
                              const DropdownMenuItem<int?>(
                                value: null,
                                child: Text('Todos'),
                              ),
                              ...List.generate(7, (index) {
                                final ano = 2024 + index;
                                return DropdownMenuItem<int?>(
                                  value: ano,
                                  child: Text(ano.toString()),
                                );
                              }),
                            ],
                            onChanged: (novoAno) {
                              setStateModal(() => _anoFiltro = novoAno);
                              setState(() => _anoFiltro = novoAno);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // 3. Filtro por Tipo de Atendimento
                    const Text('Tipo de Atendimento:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        _buildChipTipo('Todos', setStateModal),
                        _buildChipTipo('Consulta', setStateModal),
                        _buildChipTipo('Terapia', setStateModal),
                        _buildChipTipo('Retorno', setStateModal),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // 4. Filtro por Status
                    const Text('Status:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        _buildChipStatus('Todos', setStateModal),
                        _buildChipStatus('Marcada', setStateModal),
                        _buildChipStatus('Finalizada', setStateModal),
                        _buildChipStatus('Cancelada', setStateModal),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Botão de Fechar
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D6EFD),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Aplicar e Fechar', style: TextStyle(color: Colors.white, fontSize: 16)),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Dropdown estilizado para Dia, Mês e Ano
  Widget _buildDropdownData({
    required String label,
    required int? valorAtual,
    required List<DropdownMenuItem<int?>> itens,
    required ValueChanged<int?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.black54, fontSize: 12)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: valorAtual != null ? const Color(0xFF0D6EFD) : const Color(0xFFE0E0E0),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int?>(
              value: valorAtual,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.black54),
              style: const TextStyle(fontSize: 14, color: Colors.black87),
              items: itens,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  // Chips para Tipo
  Widget _buildChipTipo(String label, StateSetter setStateModal) {
    bool isSelected = _tipoFiltro.toUpperCase() == label.toUpperCase();
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selecionado) {
        if (selecionado) {
          setStateModal(() {
            _tipoFiltro = label;
          });
          setState(() {
            _tipoFiltro = label;
          });
        }
      },
      selectedColor: const Color(0xFF0D6EFD),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      backgroundColor: Colors.white,
    );
  }

  // Chips para Status
  Widget _buildChipStatus(String label, StateSetter setStateModal) {
    bool isSelected = _statusFiltro.toUpperCase() == label.toUpperCase();
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selecionado) {
        if (selecionado) {
          setStateModal(() {
            _statusFiltro = label;
          });
          setState(() {
            _statusFiltro = label;
          });
        }
      },
      selectedColor: const Color(0xFF0D6EFD),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      backgroundColor: Colors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Clientes', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list, color: Color(0xFF0D6EFD), size: 28),
            onPressed: _mostrarModalFiltros,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<List<dynamic>>(
          future: _clientesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Color(0xFF0D6EFD)));
            }
            if (snapshot.hasError) {
              return const Center(child: Text('Erro ao carregar clientes.'));
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('Nenhum cliente encontrado.', style: TextStyle(fontSize: 18, color: Colors.black54)));
            }

            final clientesFiltrados = _filtrarLista(snapshot.data!);

            if (clientesFiltrados.isEmpty) {
              return const Center(child: Text('Nenhum cliente corresponde aos filtros.', style: TextStyle(fontSize: 18, color: Colors.black54)));
            }

            return ListView.separated(
              padding: const EdgeInsets.all(24.0),
              itemCount: clientesFiltrados.length,
              separatorBuilder: (context, index) => const SizedBox(height: 24),
              itemBuilder: (context, index) {
                final cliente = clientesFiltrados[index];
                String statusBruto = cliente['status'] ?? '';
                String dataHoraBruta = (cliente['dataHora'] ?? cliente['data_hora_consulta'] ?? '').toString();

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cliente['nomePaciente'] ?? 'Sem nome',
                            style: const TextStyle(fontSize: 18, color: Colors.black87, fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatarDataHora(dataHoraBruta),
                            style: const TextStyle(fontSize: 14, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Texto do status com a cor dinâmica aplicada
                    Text(
                      _formatarStatus(statusBruto),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: _corDoStatus(statusBruto), // <-- Cores dinâmicas (Vermelho, Azul ou Padrão)
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(Icons.remove_red_eye_outlined, color: Colors.black87, size: 22),
                      tooltip: 'Ver detalhes',
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      constraints: const BoxConstraints(),
                      onPressed: () async {
                        final atualizou = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DetalhesScreen(consulta: cliente),
                          ),
                        );
                        if (atualizou == true) {
                          _carregarClientes();
                        }
                      },
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: 2,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.black54,
        showUnselectedLabels: true,
        onTap: (index) {
          if (index == 0) {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomeScreen()));
          } else if (index == 1) {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const AgendaScreen()));
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
