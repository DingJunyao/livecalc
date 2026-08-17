import '../../../core/api/api_client.dart';
import '../models/proposal.dart';
import '../models/unit_option.dart';
import '../models/user_place.dart';

class ProfileRepository {
  final ApiClient _client;
  ProfileRepository({ApiClient? client})
      : _client = client ?? ApiClient.instance;

  /// 我的提议（后端仅支持 scope/limit，返回裸数组）。
  Future<List<Proposal>> getProposals({int limit = 100}) async {
    final response = await _client.dio
        .get('/proposals', queryParameters: {'scope': 'mine', 'limit': limit});
    final list = (response.data is List)
        ? response.data as List
        : (response.data['items'] as List);
    return list
        .map((e) => Proposal.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Proposal> getProposal(int id) async {
    final response = await _client.dio.get('/proposals/$id');
    return Proposal.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<UserPlace>> getPlaces() async {
    final response = await _client.dio.get('/places');
    final list = (response.data is List)
        ? response.data as List
        : (response.data['items'] as List);
    return list
        .map((e) => UserPlace.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<UserPlace> createPlace(Map<String, dynamic> body) async {
    final response = await _client.dio.post('/places', data: body);
    return UserPlace.fromJson(response.data as Map<String, dynamic>);
  }

  Future<UserPlace> updatePlace(int id, Map<String, dynamic> body) async {
    final response = await _client.dio.put('/places/$id', data: body);
    return UserPlace.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deletePlace(int id) async {
    await _client.dio.delete('/places/$id');
  }

  Future<UserPlace> setDefaultPlace(int id) async {
    final response = await _client.dio.put('/places/$id/default');
    return UserPlace.fromJson(response.data as Map<String, dynamic>);
  }

  /// 单位列表。注意：接口是 /units/（带尾斜杠），
  /// 后端 redirect_slashes=False，不带斜杠会 404。
  Future<List<UnitOption>> getUnits() async {
    final response = await _client.dio.get('/units/');
    final list = (response.data is List)
        ? response.data as List
        : (response.data['items'] as List);
    return list
        .map((e) => UnitOption.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
