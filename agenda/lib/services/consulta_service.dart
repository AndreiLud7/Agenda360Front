import 'dart:convert';
import 'package:http/http.dart' as http;

class ConsultaService {
  static const String baseUrl = 'http://10.0.2.2:8080/v1/consultas';
// Ferramenta 1: Envia os dados para o MySQL
  Future<bool> salvarConsulta(Map<String, dynamic> dados) async {
    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(dados),
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('Erro de conexão: $e');
      return false;
    }
  }
  // Ferramenta 2: NOVA - Busca a lista de consultas do MySQL
  Future<List<dynamic>> buscarConsultas() async {
    try {
      final response = await http.get(Uri.parse(baseUrl));

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        print('Erro no servidor: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Erro de conexão ao buscar: $e');
      return [];
    }
  }
}
