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
}