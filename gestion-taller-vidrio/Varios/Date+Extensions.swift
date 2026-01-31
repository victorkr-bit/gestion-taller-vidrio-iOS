import Foundation

extension Date {
    
    func inicioDelMes() -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: self)
        return calendar.date(from: components) ?? self
    }
    
    func finDelMes() -> Date {
        let calendar = Calendar.current
        guard let inicioMes = calendar.date(from: calendar.dateComponents([.year, .month], from: self)) else {
            return self
        }
        
        var components = DateComponents()
        components.month = 1
        components.day = -1
        
        return calendar.date(byAdding: components, to: inicioMes) ?? self
    }
    
}
