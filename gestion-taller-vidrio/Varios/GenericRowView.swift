//
//  TagConfig.swift
//  (Versión Actualizada para Fecha/Hora apiladas)
//

import SwiftUI

struct TagConfig: Identifiable {
    let id = UUID()
    let text: String
    let color: Color
}

struct GenericRowView: View {
    // Datos obligatorios
    let titulo: String
    
    // Datos opcionales
    let subtitulo: String?
    let infoSuperior: String?           // LÍNEA 1 DER: Fecha (ej: 18 Ene 2026)
    let infoSuperiorSecundaria: String? // LÍNEA 2 DER: Hora (ej: 13:00) <--- NUEVO
    let iconoSuperior: String?          // Icono (ej: "calendar")
    let monto: Double?
    
    // Lista de etiquetas
    let tags: [TagConfig]
    
    // Inicializador con valores por defecto para no romper otras vistas (Pedidos, Online)
    init(titulo: String,
         subtitulo: String? = nil,
         infoSuperior: String? = nil,
         infoSuperiorSecundaria: String? = nil, // <--- NUEVO
         iconoSuperior: String? = nil,
         monto: Double? = nil,
         tags: [TagConfig] = []) {
        
        self.titulo = titulo
        self.subtitulo = subtitulo
        self.infoSuperior = infoSuperior
        self.infoSuperiorSecundaria = infoSuperiorSecundaria
        self.iconoSuperior = iconoSuperior
        self.monto = monto
        self.tags = tags
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: DesignSystem.Espaciado.m) {

            // --- COLUMNA IZQUIERDA ---
            VStack(alignment: .leading, spacing: DesignSystem.Espaciado.s) {
                Text(titulo)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                
                if let sub = subtitulo, !sub.isEmpty {
                    Text(sub)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                
                if let valor = monto {
                    Text(Formatters.money(valor))
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(DesignSystem.Color.accion)
                        .padding(.top, 2)
                }
            }
            
            Spacer()
            
            // --- COLUMNA DERECHA ---
            VStack(alignment: .trailing, spacing: DesignSystem.Espaciado.xs) {
                
                // 1. Info Superior (FECHA + Icono)
                if let info = infoSuperior {
                    HStack(spacing: 4) {
                        if let icon = iconoSuperior {
                            Image(systemName: icon)
                                .font(.caption2)
                        }
                        Text(info)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(.secondary)
                }
                
                // 2. Info Secundaria (HORA) - Debajo de la fecha
                if let sec = infoSuperiorSecundaria {
                    Text(sec)
                        .font(.subheadline) // Mismo tamaño o .caption si prefieres más chico
                        .foregroundStyle(.secondary)
                }
                
                // 3. Tags (Dejamos un espacio extra arriba si hay tags)
                //    Se apilan en columna a la derecha. Sirve cuando la izquierda está
                //    llena (Pedidos/Pagos/Deudores). InscripcionRowView NO usa esta vista:
                //    tiene layout propio con tags en fila para evitar la cascada.
                if !tags.isEmpty {
                    VStack(alignment: .trailing, spacing: DesignSystem.Espaciado.xs) {
                        ForEach(tags) { tag in
                            Text(tag.text)
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.horizontal, DesignSystem.Espaciado.s)
                                .padding(.vertical, DesignSystem.Espaciado.xs)
                                .background(tag.color.opacity(0.15))
                                .foregroundStyle(tag.color)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.top, DesignSystem.Espaciado.xs)
                }
            }
            .layoutPriority(1)
        }
        .padding(.vertical, DesignSystem.Espaciado.s)
    }
}
