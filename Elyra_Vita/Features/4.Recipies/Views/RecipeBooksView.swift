import SwiftData
import SwiftUI

struct RecipeBooksView: View {
    @Environment(\.elyraAccentColor) private var accentColor
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RecipeBook.createdAt) private var books: [RecipeBook]
    @Query private var memberships: [RecipeBookMembership]
    @State private var showingEditor = false
    @State private var editingBook: RecipeBook?
    @State private var deletingBook: RecipeBook?

    var body: some View {
        NavigationStack {
            List {
                if books.isEmpty {
                    ContentUnavailableView(
                        "Noch keine Rezeptbücher",
                        systemImage: "books.vertical",
                        description: Text("Lege ein Rezeptbuch an, um deine Rezepte zu organisieren.")
                    )
                } else {
                    ForEach(books) { book in
                        HStack {
                            Label(book.name, systemImage: "book")
                            Spacer()
                            Text("\(memberships.filter { $0.bookID == book.id }.count)")
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { editingBook = book }
                        .swipeActions {
                            Button("Löschen", role: .destructive) { deletingBook = book }
                            Button("Bearbeiten") { editingBook = book }
                                .tint(accentColor)
                        }
                    }
                }
            }
            .navigationTitle("Rezeptbücher")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Fertig") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button { showingEditor = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Rezeptbuch anlegen")
                }
            }
            .sheet(isPresented: $showingEditor) { RecipeBookEditorView() }
            .sheet(item: $editingBook) { RecipeBookEditorView(book: $0) }
            .alert(
                "Rezeptbuch löschen?",
                isPresented: deletingPresented,
                presenting: deletingBook
            ) { book in
                Button("Löschen", role: .destructive) { delete(book) }
                Button("Abbrechen", role: .cancel) { deletingBook = nil }
            } message: { book in
                Text("\"\(book.name)\" wird gelöscht. Die Rezepte bleiben erhalten.")
            }
        }
    }

    private func delete(_ book: RecipeBook) {
        memberships.filter { $0.bookID == book.id }.forEach(modelContext.delete)
        modelContext.delete(book)
        if PersistenceErrorReporter.save(modelContext, operation: "Rezeptbuch löschen") {
            deletingBook = nil
        }
    }

    private var deletingPresented: Binding<Bool> {
        Binding(get: { deletingBook != nil }, set: {
            if !$0 {
                deletingBook = nil
            }
        })
    }
}

struct RecipeBookEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let book: RecipeBook?
    @State private var name: String

    init(book: RecipeBook? = nil) {
        self.book = book
        _name = State(initialValue: book?.name ?? "")
    }

    var body: some View {
        NavigationStack {
            Form { TextField("Name des Rezeptbuchs", text: $name) }
                .navigationTitle(book == nil ? "Neues Rezeptbuch" : "Rezeptbuch bearbeiten")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Sichern") { save() }
                            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
        }
        .presentationDetents([.height(190)])
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let book {
            book.name = trimmedName
            book.updatedAt = .now
        } else {
            modelContext.insert(RecipeBook(name: trimmedName))
        }
        if PersistenceErrorReporter.save(modelContext, operation: "Rezeptbuch speichern") {
            dismiss()
        }
    }
}
