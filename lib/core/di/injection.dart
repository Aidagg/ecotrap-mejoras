import 'package:get_it/get_it.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../features/files/data/datasources/files_remote_datasource.dart';
import '../../features/files/data/repositories/files_repository_impl.dart';
import '../../features/files/domain/repositories/files_repository.dart';
import '../../features/files/domain/usecases/download_file.dart';
import '../../features/files/domain/usecases/get_files.dart';
import '../../features/files/presentation/bloc/files_bloc.dart';
import '../../features/wifi/data/datasources/wifi_local_datasource.dart';
import '../../features/wifi/data/models/wifi_network_model.dart';
import '../../features/wifi/data/repositories/wifi_repository_impl.dart';
import '../../features/wifi/domain/repositories/wifi_repository.dart';
import '../../features/wifi/domain/usecases/delete_wifi_network.dart';
import '../../features/wifi/domain/usecases/get_total_count.dart';
import '../../features/wifi/domain/usecases/get_wifi_networks.dart';
import '../../features/wifi/domain/usecases/save_wifi_network.dart';
import '../../features/wifi/domain/usecases/update_wifi_network.dart';
import '../../features/wifi/presentation/bloc/wifi_bloc.dart';
import '../network/api_service.dart';
import '../services/wifi_connection_service.dart'; // NUEVO

final sl = GetIt.instance;

Future<void> initDependencies() async {
  // ============================================================
  // External Dependencies
  // ============================================================
  
  await Hive.initFlutter();
  Hive.registerAdapter(WiFiNetworkModelAdapter());
  await Hive.openBox<WiFiNetworkModel>('wifi_networks');
  
  sl.registerLazySingleton<HiveInterface>(() => Hive);
  sl.registerLazySingleton<Uuid>(() => const Uuid());
  
  // NUEVO: WiFi Connection Service
  sl.registerLazySingleton<WiFiConnectionService>(() => WiFiConnectionService());

  // ============================================================
  // Data Layer
  // ============================================================
  
  sl.registerLazySingleton<WiFiLocalDataSource>(
    () => WiFiLocalDataSourceImpl(hive: sl()),
  );
  
  sl.registerLazySingleton<WiFiRepository>(
    () => WiFiRepositoryImpl(
      localDataSource: sl(),
      uuid: sl(),
    ),
  );

  // ============================================================
  // Domain Layer - Use Cases
  // ============================================================
  
  sl.registerLazySingleton(() => GetWiFiNetworks(sl()));
  sl.registerLazySingleton(() => SaveWiFiNetwork(sl()));
  sl.registerLazySingleton(() => UpdateWiFiNetwork(sl()));
  sl.registerLazySingleton(() => DeleteWiFiNetwork(sl()));
  sl.registerLazySingleton(() => GetTotalCount(sl()));

  // ============================================================
  // Presentation Layer - BLoC
  // ============================================================
  
  sl.registerFactory(
    () => WiFiBloc(
      getWiFiNetworks: sl(),
      saveWiFiNetwork: sl(),
      updateWiFiNetwork: sl(),
      deleteWiFiNetwork: sl(),
      getTotalCount: sl(),
    ),
  );
  // ===================================
  // Files Feature
  // ===================================

  // API Service (si no existe ya)
  sl.registerLazySingleton<ApiService>(() => ApiService());

  // Data sources
  sl.registerLazySingleton<FilesRemoteDataSource>(
    () => FilesRemoteDataSourceImpl(sl()),
  );

  // Repositories
  sl.registerLazySingleton<FilesRepository>(
    () => FilesRepositoryImpl(sl()),
  );

  // Use cases
  sl.registerLazySingleton(() => GetFiles(sl()));
  sl.registerLazySingleton(() => DownloadFile(sl()));

  // BLoC
  sl.registerFactory(
    () => FilesBloc(
      getFiles: sl(),
      downloadFile: sl(),
    ),
  );
}