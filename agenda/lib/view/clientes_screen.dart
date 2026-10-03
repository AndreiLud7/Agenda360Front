import 'package:flutter/material.dart';
import 'package:agenda/services/consulta_service.dart';

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

  // Controlador para ler o que for digitado no campo de texto
  final TextEditingController _buscaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _clientesFuture = _consultaService.buscarConsultas();
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

  // Nova lógica de filtro: verifica o Nome e o Tipo ao mesmo tempo
  List<dynamic> _filtrarLista(List<dynamic> todosClientes) {
    return todosClientes.where((cliente) {
      String nome = (cliente['nomePaciente'] ?? '').toString().toLowerCase();
      String tipo = (cliente['tipo'] ?? '').toString().toUpperCase();

      // Regra 1: O nome digitado está contido no nome do paciente?
      bool passaNome = _nomeBusca.isEmpty || nome.contains(_nomeBusca.toLowerCase());

      // Regra 2: O tipo selecionado é igual ao tipo que veio do banco?
      bool passaTipo = _tipoFiltro == 'Todos' || tipo == _tipoFiltro.toUpperCase();

      // Só mostra na tela se passar nas duas regras
      return passaNome && passaTipo;
    }).toList();
  }

  // Desenha a aba que sobe de baixo para cima com os filtros
  void _mostrarModalFiltros() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Permite que a aba suba junto com o teclado
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        // O StatefulBuilder é necessário para atualizar apenas o que está dentro do Modal
        return StatefulBuilder(
            builder: (context, setStateModal) {
              return Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom, // Evita que o teclado cubra os botões
                  left: 24,
                  right: 24,
                  top: 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min, // Ocupa apenas o tamanho necessário
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Filtrar Clientes', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
                        // Atualiza a tela principal enquanto você digita
                        setState(() {
                          _nomeBusca = valor;
                        });
                      },
                    ),
                    const SizedBox(height: 24),

                    // 2. Filtro por Tipo de Atendimento (Botões de escolha)
                    const Text('Tipo de Atendimento:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        _buildChipOpcao('Todos', setStateModal),
                        _buildChipOpcao('Consulta', setStateModal),
                        _buildChipOpcao('Terapia', setStateModal),
                        _buildChipOpcao('Retorno', setStateModal), // Adicione outros se precisar
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
              );
            }
        );
      },
    );
  }

  // Funçãozinha para desenhar as opções do Tipo de Terapia
  Widget _buildChipOpcao(String label, StateSetter setStateModal) {
    bool isSelected = _tipoFiltro.toUpperCase() == label.toUpperCase();
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selecionado) {
        if (selecionado) {
          setStateModal(() {
            _tipoFiltro = label; // Atualiza a cor dentro do modal
          });
          setState(() {
            _tipoFiltro = label; // Atualiza a lista lá atrás na tela principal
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
          // ÍCONE NOVO DE FILTRO AQUI NO TOPO À DIREITA
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
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        cliente['nomePaciente'] ?? 'Sem nome',
                        style: const TextStyle(fontSize: 18, color: Colors.black87, fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      _formatarStatus(cliente['status'] ?? ''),
                      style: const TextStyle(fontSize: 16, color: Colors.black54),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}