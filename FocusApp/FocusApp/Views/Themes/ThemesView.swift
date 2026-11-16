import SwiftUI

enum QuoteEditTarget: Identifiable {
    case new
    case edit(Quote)

    var id: String {
        switch self {
        case .new: return "new"
        case .edit(let quote): return quote.id.uuidString
        }
    }

    var quote: Quote? {
        if case .edit(let quote) = self { return quote }
        return nil
    }
}

struct ThemesView: View {
    @Environment(AppModel.self) private var model
    @State private var editingQuote: QuoteEditTarget?

    var body: some View {
        @Bindable var model = model

        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.l) {
                ScreenHeader("Themes", subtitle: "What you see when an app is blocked")

                // Live preview
                BlockScreenView(theme: model.theme, quote: model.currentQuote.text, scale: 0.72)
                    .frame(height: 420)
                    .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .strokeBorder(DS.Palette.stroke, lineWidth: 1)
                    )
                    .animation(.easeInOut(duration: 0.3), value: model.theme)

                VStack(alignment: .leading, spacing: DS.Space.s) {
                    SectionLabel("Theme")
                    Card {
                        ForEach(BlockTheme.allCases) { theme in
                            ThemeRow(theme: theme, isSelected: theme == model.theme) {
                                model.theme = theme
                            }
                            if theme != BlockTheme.allCases.last { RowDivider() }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: DS.Space.s) {
                    SectionLabel("Quote")

                    Picker("Quote mode", selection: $model.quoteMode) {
                        ForEach(QuoteMode.allCases, id: \.self) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.bottom, 4)

                    Card {
                        let quotes = model.allQuotes
                        let current = model.currentQuote.id
                        ForEach(quotes) { quote in
                            QuoteRow(quote: quote,
                                     isCurrent: quote.id == current,
                                     onSelect: { model.selectQuote(quote) },
                                     onEdit: quote.isCustom ? { editingQuote = .edit(quote) } : nil,
                                     onDelete: quote.isCustom ? { model.deleteQuote(quote) } : nil)
                            if quote.id != quotes.last?.id { RowDivider(inset: 16) }
                        }
                    }

                    Button {
                        editingQuote = .new
                    } label: {
                        Label("Add your own", systemImage: "plus")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .padding(.top, 4)
                }
            }
            .padding(.horizontal, DS.Space.gutter)
            .padding(.bottom, DS.Space.xl)
        }
        .scrollIndicators(.hidden)
        .background(DS.Palette.background.ignoresSafeArea())
        .sheet(item: $editingQuote) { target in
            QuoteEditorView(target: target)
        }
    }
}

// MARK: - Rows

private struct ThemeRow: View {
    let theme: BlockTheme
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        let palette = theme.palette
        Button(action: onSelect) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(palette.background)
                    Circle().strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                    Circle().fill(palette.accent).frame(width: 10, height: 10)
                }
                .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 2) {
                    Text(theme.name)
                        .font(DS.Typography.body.weight(.medium))
                        .foregroundStyle(DS.Palette.text)
                    Text(theme.subtitle)
                        .font(DS.Typography.footnote)
                        .foregroundStyle(DS.Palette.secondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(DS.Palette.accent)
                }
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 66)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}

private struct QuoteRow: View {
    let quote: Quote
    let isCurrent: Bool
    let onSelect: () -> Void
    let onEdit: (() -> Void)?
    let onDelete: (() -> Void)?

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(quote.text)
                .font(DS.Typography.subheadline)
                .foregroundStyle(isCurrent ? DS.Palette.text : DS.Palette.secondary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let onEdit {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(DS.Palette.tertiary)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
            }

            Image(systemName: "checkmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DS.Palette.accent)
                .opacity(isCurrent ? 1 : 0)
        }
        .padding(.leading, 16)
        .padding(.trailing, 14)
        .frame(minHeight: 58)
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .contextMenu {
            Button("Pin this quote", systemImage: "pin", action: onSelect)
            if let onEdit { Button("Edit", systemImage: "pencil", action: onEdit) }
            if let onDelete { Button("Delete", systemImage: "trash", role: .destructive, action: onDelete) }
        }
    }
}
