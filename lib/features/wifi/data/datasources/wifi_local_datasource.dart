import 'package:hive/hive.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/wifi_network_model.dart';

/// Abstract DataSource
/// 
/// Interface Segregation (SOLID): Define contrato específico para datos locales
abstract class WiFiLocalDataSource {
  /// Obtiene todas las redes WiFi con paginación
  Future<List<WiFiNetworkModel>> getWiFiNetworks({
    required int page,
    required int pageSize,
  });
  
  /// Obtiene una red WiFi por ID
  Future<WiFiNetworkModel> getWiFiNetworkById(String id);
  
  /// Guarda una nueva red WiFi
  Future<WiFiNetworkModel> saveWiFiNetwork(WiFiNetworkModel network);
  
  /// Actualiza una red WiFi existente
  Future<WiFiNetworkModel> updateWiFiNetwork(WiFiNetworkModel network);
  
  /// Elimina una red WiFi
  Future<void> deleteWiFiNetwork(String id);
  
  /// Obtiene el total de redes
  Future<int> getTotalCount();
}

/// Implementación con Hive
/// 
/// Single Responsibility: Solo maneja el almacenamiento local con Hive
class WiFiLocalDataSourceImpl implements WiFiLocalDataSource {
  static const String boxName = 'wifi_networks';
  final HiveInterface hive;

  WiFiLocalDataSourceImpl({required this.hive});

  /// Helper: Obtiene la caja de Hive de forma segura
  Box<WiFiNetworkModel> _getBox() {
    try {
      return hive.box<WiFiNetworkModel>(boxName);
    } catch (e) {
      throw CacheException('Error al acceder a la base de datos local: ${e.toString()}');
    }
  }

  @override
  Future<List<WiFiNetworkModel>> getWiFiNetworks({
    required int page,
    required int pageSize,
  }) async {
    try {
      final box = _getBox();
      
      // Obtener todos los valores
      final allNetworks = box.values.toList();
      
      // Ordenar por fecha de creación (más recientes primero)
      allNetworks.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      // Calcular índices de paginación
      final startIndex = (page - 1) * pageSize;
      final endIndex = startIndex + pageSize;
      
      // Validar rangos
      if (startIndex >= allNetworks.length) {
        return [];
      }
      
      // Retornar página solicitada
      final actualEndIndex = endIndex > allNetworks.length 
          ? allNetworks.length 
          : endIndex;
      
      return allNetworks.sublist(startIndex, actualEndIndex);
    } catch (e) {
      if (e is CacheException) rethrow;
      throw CacheException('Error al obtener redes WiFi: ${e.toString()}');
    }
  }

  @override
  Future<WiFiNetworkModel> getWiFiNetworkById(String id) async {
    try {
      final box = _getBox();
      
      final network = box.get(id);
      
      if (network == null) {
        throw NotFoundException('Red WiFi con ID $id no encontrada');
      }
      
      return network;
    } catch (e) {
      if (e is NotFoundException || e is CacheException) rethrow;
      throw CacheException('Error al buscar red WiFi: ${e.toString()}');
    }
  }

  @override
  Future<WiFiNetworkModel> saveWiFiNetwork(WiFiNetworkModel network) async {
    try {
      final box = _getBox();

      // Duplicado = mismo SSID Y (mismo BSSID o alguna sin BSSID).
      // Si ambas tienen BSSID distintos → son dispositivos diferentes → permitido.
      final existingNetworks = box.values.where((n) {
        if (n.ssid.toLowerCase() != network.ssid.toLowerCase()) return false;
        final hasNewBssid =
            network.bssid != null && network.bssid!.isNotEmpty;
        final hasExistingBssid = n.bssid != null && n.bssid!.isNotEmpty;
        if (hasNewBssid && hasExistingBssid) {
          return n.bssid!.toLowerCase() == network.bssid!.toLowerCase();
        }
        return true; // sin BSSID → duplicado por SSID
      }).toList();

      if (existingNetworks.isNotEmpty) {
        throw ValidationException(
          'Ya existe una red WiFi con el nombre "${network.ssid}"'
          '${network.bssid != null && network.bssid!.isNotEmpty ? ' y BSSID "${network.bssid}"' : ''}'
        );
      }
      
      // Guardar en Hive usando el ID como key
      await box.put(network.id, network);
      
      return network;
    } catch (e) {
      if (e is ValidationException || e is CacheException) rethrow;
      throw CacheException('Error al guardar red WiFi: ${e.toString()}');
    }
  }

  @override
  Future<WiFiNetworkModel> updateWiFiNetwork(WiFiNetworkModel network) async {
    try {
      final box = _getBox();
      
      // Verificar que exista
      if (!box.containsKey(network.id)) {
        throw NotFoundException('Red WiFi con ID ${network.id} no encontrada');
      }
      
      // Misma lógica que en save: duplicado solo si SSID y BSSID coinciden
      final existingNetworks = box.values.where((n) {
        if (n.id == network.id) return false; // ignorar self
        if (n.ssid.toLowerCase() != network.ssid.toLowerCase()) return false;
        final hasNewBssid =
            network.bssid != null && network.bssid!.isNotEmpty;
        final hasExistingBssid = n.bssid != null && n.bssid!.isNotEmpty;
        if (hasNewBssid && hasExistingBssid) {
          return n.bssid!.toLowerCase() == network.bssid!.toLowerCase();
        }
        return true;
      }).toList();

      if (existingNetworks.isNotEmpty) {
        throw ValidationException(
          'Ya existe otra red WiFi con el nombre "${network.ssid}"'
          '${network.bssid != null && network.bssid!.isNotEmpty ? ' y BSSID "${network.bssid}"' : ''}'
        );
      }
      
      // Actualizar timestamp
      final updatedNetwork = network.copyWithModel(
        updatedAt: DateTime.now(),
      );
      
      // Actualizar en Hive
      await box.put(updatedNetwork.id, updatedNetwork);
      
      return updatedNetwork;
    } catch (e) {
      if (e is NotFoundException || 
          e is ValidationException || 
          e is CacheException) {
        rethrow;
      }
      throw CacheException('Error al actualizar red WiFi: ${e.toString()}');
    }
  }

  @override
  Future<void> deleteWiFiNetwork(String id) async {
    try {
      final box = _getBox();
      
      // Verificar que exista
      if (!box.containsKey(id)) {
        throw NotFoundException('Red WiFi con ID $id no encontrada');
      }
      
      // Eliminar de Hive
      await box.delete(id);
    } catch (e) {
      if (e is NotFoundException || e is CacheException) rethrow;
      throw CacheException('Error al eliminar red WiFi: ${e.toString()}');
    }
  }

  @override
  Future<int> getTotalCount() async {
    try {
      final box = _getBox();
      return box.length;
    } catch (e) {
      if (e is CacheException) rethrow;
      throw CacheException('Error al contar redes WiFi: ${e.toString()}');
    }
  }
}