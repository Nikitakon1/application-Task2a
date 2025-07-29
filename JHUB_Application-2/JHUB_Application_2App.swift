//
//  JHUB_Application_2App.swift
//  JHUB_Application-2
//
//  Created by Nikita on 29/07/2025.
//

import SwiftUI

@main
struct JHUB_Application_2App: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
