import 'dart:convert';
import 'package:http/http.dart' as http;

class ConsultaService {
  static const String baseUrl = 'http://10.0.2.2:8080/v1/consultas';
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

  Future<bool> editarConsulta(String id, Map<String, dynamic> dados) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/$id'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(dados),
      );

      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      print('Erro de conexão ao editar: $e');
      return false;
    }
  }

  Future<bool> cancelarConsulta(String id) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/cancelar/$id'),
      );
      // O Spring Boot devolve 204 NO_CONTENT nas suas rotas PATCH
      return response.statusCode == 204 || response.statusCode == 200;
    } catch (e) {
      print('Erro de conexão ao cancelar: $e');
      return false;
    }
  }

  Future<bool> finalizarConsulta(String id) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/finalizar/$id'),
      );
      // O Spring Boot devolve 204 NO_CONTENT nas suas rotas PATCH
      return response.statusCode == 204 || response.statusCode == 200;
    } catch (e) {
      print('Erro de conexão ao finalizar: $e');
      return false;
    }
  }
}
