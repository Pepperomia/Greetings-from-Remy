import Foundation

enum DatabaseBootstrap {
    // MARK: - Configuration
    
    static let dbFileName = "recipes_app_seed_final.sqlite"
    static let appDirectoryName = "GreetingsFromRemy"
    
    // MARK: - Public Methods
    
    /// Возвращает URL для базы данных в Application Support
    static func appDatabaseURL() -> URL {
        do {
            let appSupport = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            
            let appDir = appSupport.appendingPathComponent(appDirectoryName, isDirectory: true)
            
            // Создаём директорию, если её нет
            if !FileManager.default.fileExists(atPath: appDir.path) {
                try FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
            }
            
            return appDir.appendingPathComponent(dbFileName)
            
        } catch {
            fatalError("❌ Не удалось создать директорию для базы данных: \(error.localizedDescription)")
        }
    }
    
    /// Копирует базу данных из Bundle в Application Support (если её там нет)
    @discardableResult
    static func ensureDatabaseCopiedFromBundle() -> Bool {
        let destinationURL = appDatabaseURL()
        let fileManager = FileManager.default
        
        // Проверяем, есть ли уже база
        if fileManager.fileExists(atPath: destinationURL.path) {
            print("✅ База данных уже существует: \(destinationURL.lastPathComponent)")
            return true
        }
        
        // Ищем базу в Bundle
        guard let sourceURL = Bundle.main.url(forResource: dbFileName.replacingOccurrences(of: ".sqlite", with: ""),
                                              withExtension: "sqlite") else {
            print("❌ Файл базы данных не найден в Bundle. Убедись, что \(dbFileName) добавлен в проект.")
            return false
        }
        
        do {
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
            print("✅ База данных скопирована в: \(destinationURL.path)")
            
            // Проверяем, что файл действительно скопировался
            var isDirectory: ObjCBool = false
            let exists = fileManager.fileExists(atPath: destinationURL.path, isDirectory: &isDirectory)
            
            if exists && !isDirectory.boolValue {
                print("✅ Файл успешно скопирован и доступен")
                return true
            } else {
                print("⚠️ Файл скопирован, но не удаётся проверить его доступность")
                return false
            }
            
        } catch let error as NSError {
            print("❌ Ошибка копирования базы данных: \(error.localizedDescription)")
            print("   Код ошибки: \(error.code)")
            print("   Детали: \(error.userInfo)")
            return false
        }
    }
    
    /// Проверяет существование базы данных и её размер
    static func checkDatabaseStatus() {
        let url = appDatabaseURL()
        let fileManager = FileManager.default
        
        guard fileManager.fileExists(atPath: url.path) else {
            print("❌ База данных отсутствует по пути: \(url.path)")
            return
        }
        
        do {
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            if let size = attributes[.size] as? NSNumber {
                let sizeInMB = Double(size.int64Value) / 1_048_576.0
                print("📊 База данных: \(url.lastPathComponent)")
                print("   Размер: \(String(format: "%.2f", sizeInMB)) MB")
                print("   Путь: \(url.path)")
            }
        } catch {
            print("❌ Не удалось получить информацию о файле: \(error.localizedDescription)")
        }
    }
    
    /// Удаляет существующую базу данных (для отладки)
    static func removeDatabase() throws {
        let url = appDatabaseURL()
        let fileManager = FileManager.default
        
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
            print("🗑️ База данных удалена: \(url.lastPathComponent)")
        }
    }
    
    /// Получает версию базы данных (если есть таблица version)
    static func getDatabaseVersion() -> String? {
        // Можно добавить, если в базе есть таблица с версией
        return nil
    }
}
