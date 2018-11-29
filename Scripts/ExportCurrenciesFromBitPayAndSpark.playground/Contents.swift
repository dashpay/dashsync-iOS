import UIKit
import PlaygroundSupport

struct BitPayRates: Codable {
    let items: [BitPayRate]
    
    enum CodingKeys : String, CodingKey {
        case items = "data"
    }
}

struct BitPayRate: Codable {
    let code: String
    let name: String
}

////////////////////////////////////////////////////////

let bitpayRatesData = try! Data(contentsOf: URL(string: "https://bitpay.com/rates")!)
var bitPayRates = try! JSONDecoder().decode(BitPayRates.self, from: bitpayRatesData)
let skipBitPayCurrencies = ["BTC", "BCH"]
let bitPayItems = bitPayRates.items.filter { !skipBitPayCurrencies.contains($0.code) }
var currenciesBitPay = bitPayItems.map { $0.code }

let sparkRatesData = try! Data(contentsOf: URL(string: "https://api.get-spark.com/list")!)
let sparkRates: [String:Any] = try! JSONSerialization.jsonObject(with: sparkRatesData, options: .init(rawValue: 0)) as! [String:Any]
let currenciesSpark = sparkRates.keys

let notInSpark = currenciesBitPay.filter { !currenciesSpark.contains($0) }
let notInBitPay = currenciesSpark.filter { !currenciesBitPay.contains($0) }

print("Not in Spark but in BitPay:", notInSpark.count, notInSpark)
print("Not in BitPay but in Spark:", notInBitPay.count, notInBitPay)

var currencyNamesByCode: [String: String] = [:]
for item in bitPayItems {
    currencyNamesByCode[item.code] = item.name
}

let documentDirectory = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
let url = URL(fileURLWithPath: documentDirectory).appendingPathComponent("CurrenciesByCode.plist")
let encoder = PropertyListEncoder()
encoder.outputFormat = .xml
let data = try encoder.encode(currencyNamesByCode)
try! data.write(to: url)

print("Exported to: ")
print(url.path)
