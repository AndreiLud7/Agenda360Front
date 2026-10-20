import 'dart:io';
import 'package:flutter/material.dart';
import 'package:agenda/services/consulta_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart'; // Pacote do visualizador de PDF

// Importações de navegação
import 'package:agenda/view/home_screen.dart';
import 'package:agenda/view/agenda_screen.dart';
import 'package:agenda/view/clientes_screen.dart';

class AtestadoScreen extends StatefulWidget {
  const AtestadoScreen({super.key});

  @override
  State<AtestadoScreen> createState() => _AtestadoScreenState();
}

class _AtestadoScreenState extends State<AtestadoScreen> {
  final _consultaService = ConsultaService();
  late Future<List<dynamic>> _consultasFuture;
  bool _isLoadingAction = false; // Controle de loading para download ou prévia

  @override
  void initState() {
    super.initState();
    _consultasFuture = _consultaService.buscarConsultas();
  }

  List<dynamic> _filtrarFinalizados(List<dynamic> consultas) {
    return consultas.where((c) {
      String status = (c['statusConsulta'] ?? c['status'] ?? '').toString();
      return status == 'CONSULTA_FINALIZADA' ||
          status == 'TERAPIA_FINALIZADA' ||
          status == 'RETORNO_FINALIZADO';
    }).toList();
  }

  String _formatarData(String dataString) {
    if (dataString.isEmpty) return '';
    try {
      String apenasData = dataString.contains('T')
          ? dataString.split('T')[0]
          : dataString.split(' ')[0];

      List<String> partes = apenasData.split('-');
      if (partes.length == 3) {
        return '${partes[2]}/${partes[1]}/${partes[0]}';
      }
      return dataString;
    } catch (e) {
      return dataString;
    }
  }

  String _formatarTipo(String tipoCru) {
    if (tipoCru.isEmpty) return '';
    String texto = tipoCru.toLowerCase();
    return texto[0].toUpperCase() + texto.substring(1);
  }

  // --- FUNÇÃO: PRÉVIA DO PDF COM BOTÃO DE COMPARTILHAR ---
  Future<void> _abrirPrevia(String id, String nomePaciente) async {
    setState(() { _isLoadingAction = true; });

    try {
      final pdfBytes = await _consultaService.baixarAtestado(id);

      if (pdfBytes != null) {
        if (!mounted) return;

        // Navega para uma nova tela contendo o visualizador de PDF
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => Scaffold(
              appBar: AppBar(
                title: Text('Prévia: $nomePaciente', style: const TextStyle(fontSize: 18)),
                backgroundColor: const Color(0xFF0D6EFD),
                foregroundColor: Colors.white,
                // Adicionamos o botão de compartilhar no canto direito da barra
                actions: [
                  IconButton(
                    icon: const Icon(Icons.share),
                    tooltip: 'Compartilhar / Salvar',
                    onPressed: () async {
                      try {
                        // Reutiliza os bytes do PDF já baixados!
                        final tempDir = await getTemporaryDirectory();
                        String nomeArquivo = nomePaciente.replaceAll(' ', '_');
                        File file = File('${tempDir.path}/atestado_$nomeArquivo.pdf');

                        await file.writeAsBytes(pdfBytes);

                        // Abre a tela de compartilhamento do celular
                        await Share.shareXFiles([XFile(file.path)], text: 'Atestado de $nomePaciente');
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Erro ao exportar arquivo.'), backgroundColor: Colors.red),
                        );
                      }
                    },
                  ),
                ],
              ),
              // O SfPdfViewer renderiza os bytes diretamente na tela
              body: SfPdfViewer.memory(pdfBytes),
            ),
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao carregar a prévia.'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao processar o arquivo.'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() { _isLoadingAction = false; });
    }
  }

  // --- FUNÇÃO DE DOWNLOAD/COMPARTILHAR DIRETO ---
  Future<void> _fazerDownloadAtestado(String id, String nomePaciente) async {
    setState(() { _isLoadingAction = true; });

    try {
      final pdfBytes = await _consultaService.baixarAtestado(id);

      if (pdfBytes != null) {
        final tempDir = await getTemporaryDirectory();
        String nomeArquivo = nomePaciente.replaceAll(' ', '_');
        File file = File('${tempDir.path}/atestado_$nomeArquivo.pdf');

        await file.writeAsBytes(pdfBytes);

        // Abre a tela de compartilhamento direto
        await Share.shareXFiles([XFile(file.path)], text: 'Atestado de $nomePaciente');
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao baixar o atestado.'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao processar o arquivo.'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() { _isLoadingAction = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Gerar Atestado',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  if (_isLoadingAction)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0D6EFD)),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: FutureBuilder<List<dynamic>>(
                  future: _consultasFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Color(0xFF0D6EFD)));
                    }
                    if (snapshot.hasError) {
                      return const Center(child: Text('Erro ao carregar atestados.'));
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(child: Text('Nenhum registro encontrado.'));
                    }

                    final finalizadas = _filtrarFinalizados(snapshot.data!);

                    if (finalizadas.isEmpty) {
                      return const Center(
                        child: Text(
                          'Nenhum atendimento finalizado disponível.',
                          style: TextStyle(fontSize: 16, color: Colors.black54),
                        ),
                      );
                    }

                    return ListView.separated(
                      itemCount: finalizadas.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final consulta = finalizadas[index];
                        String nome = consulta['nomePaciente'] ?? 'Sem nome';
                        String tipo = _formatarTipo(consulta['tipo'] ?? '');
                        String data = _formatarData(consulta['data_hora_consulta'] ?? consulta['dataHora'] ?? '');

                        return Container(
                          padding: const EdgeInsets.only(left: 16, right: 8, top: 12, bottom: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9F5F5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  '$nome - $tipo $data',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black87,
                                    fontWeight: FontWeight.w400,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              // Grupo de botões à direita (Olho e Compartilhar)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove_red_eye_outlined, color: Colors.black87),
                                    onPressed: () {
                                      if (!_isLoadingAction) {
                                        _abrirPrevia(consulta['id'] ?? '', nome);
                                      }
                                    },
                                    tooltip: 'Visualizar',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.share, color: Colors.black87),
                                    onPressed: () {
                                      if (!_isLoadingAction) {
                                        // Chama a função direta, sem passar pelo Dialog
                                        _fazerDownloadAtestado(consulta['id'] ?? '', nome);
                                      }
                                    },
                                    tooltip: 'Compartilhar',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: 4,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.black54,
        showUnselectedLabels: true,
        onTap: (index) {
          if (index == 0) {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomeScreen()));
          } else if (index == 1) {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const AgendaScreen()));
          } else if (index == 2) {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const ClientesScreen()));
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