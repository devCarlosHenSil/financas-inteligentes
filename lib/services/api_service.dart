import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  Future<double> getBitcoinPrice() async {
    final response = await http.get(Uri.parse('https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=brl'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['bitcoin']['brl'];
    } else {
      throw Exception('Falha ao carregar preço');
    }
  }
}