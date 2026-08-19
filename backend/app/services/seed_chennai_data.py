from __future__ import annotations

import structlog
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.safety import PoliceStation, SafetyZone

logger = structlog.get_logger()

# ─── 1. CHENNAI POLICE STATIONS DATASET (116 STATIONS) ──────────────────────
CHENNAI_POLICE_STATIONS_DATA = [
    # North Zone
    {"zone": "North", "sub_division": "Flower Bazaar", "station_name": "C1 Flower Bazaar", "contact_number": "04423452464;465", "lat": 13.0892, "lng": 80.2825, "address": "Flower Bazaar, George Town, Chennai"},
    {"zone": "North", "sub_division": "Flower Bazaar", "station_name": "C2 Elephant Gate", "contact_number": "04423452467;468", "lat": 13.0877, "lng": 80.2758, "address": "Elephant Gate, Park Town, Chennai"},
    {"zone": "North", "sub_division": "Flower Bazaar", "station_name": "C3 Seven Wells", "contact_number": "04423452471;472", "lat": 13.0945, "lng": 80.2842, "address": "Seven Wells, George Town, Chennai"},
    {"zone": "North", "sub_division": "Flower Bazaar", "station_name": "C4 Government Hospital", "contact_number": "04423452473", "lat": 13.0818, "lng": 80.2798, "address": "GH Road, Park Town, Chennai"},
    {"zone": "North", "sub_division": "High Court", "station_name": "B2 Esplanade", "contact_number": "04423452458;459", "lat": 13.0886, "lng": 80.2886, "address": "Esplanade, George Town, Chennai"},
    {"zone": "North", "sub_division": "High Court", "station_name": "B4 High Court", "contact_number": "04423452462", "lat": 13.0872, "lng": 80.2872, "address": "High Court Complex, Chennai"},
    {"zone": "North", "sub_division": "Harbour", "station_name": "B5 Harbour", "contact_number": "04423452500;501", "lat": 13.0968, "lng": 80.2941, "address": "Harbour, Chennai Port, Chennai"},
    {"zone": "North", "sub_division": "Harbour", "station_name": "B1 North Beach", "contact_number": "04423452457;457", "lat": 13.0924, "lng": 80.2932, "address": "Rajaji Salai, North Beach, Chennai"},
    {"zone": "North", "sub_division": "Harbour", "station_name": "B3 Fort", "contact_number": "04423452460;461", "lat": 13.0792, "lng": 80.2878, "address": "Fort St. George, Chennai"},
    {"zone": "North", "sub_division": "Harbour", "station_name": "N3 Muthialpet", "contact_number": "04423452514;515", "lat": 13.0984, "lng": 80.2891, "address": "Muthialpet, George Town, Chennai"},
    {"zone": "North", "sub_division": "Harbour", "station_name": "C5 Kothavalchavadi", "contact_number": "04423452474;474", "lat": 13.0911, "lng": 80.2819, "address": "Kothawal Chavadi, George Town, Chennai"},
    {"zone": "North", "sub_division": "Port Marine", "station_name": "B6 Port Marine", "contact_number": "04423452502", "lat": 13.0950, "lng": 80.2980, "address": "Chennai Port Trust, Chennai"},
    {"zone": "North", "sub_division": "Washermenpet", "station_name": "H1 Washermenpet", "contact_number": "04423452481;481", "lat": 13.1097, "lng": 80.2815, "address": "Washermanpet, Chennai"},
    {"zone": "North", "sub_division": "Washermenpet", "station_name": "H3 Tondiarpet", "contact_number": "04423452485;486", "lat": 13.1239, "lng": 80.2879, "address": "Tondiarpet, Chennai"},
    {"zone": "North", "sub_division": "Washermenpet", "station_name": "H4 Korukkupet", "contact_number": "04423452488;489", "lat": 13.1182, "lng": 80.2731, "address": "Korukkupet, Chennai"},
    {"zone": "North", "sub_division": "Washermenpet", "station_name": "H6 R K Nagar", "contact_number": "04423452493;494", "lat": 13.1311, "lng": 80.2834, "address": "R.K. Nagar, Chennai"},
    {"zone": "North", "sub_division": "Washermenpet", "station_name": "H2 Stanley Hospital", "contact_number": "04425281347", "lat": 13.1053, "lng": 80.2842, "address": "Stanley Hospital, Old Jail Road, Chennai"},
    {"zone": "North", "sub_division": "Thiruvottiyur", "station_name": "H8 Thiruvottiyur", "contact_number": "04423452496;497", "lat": 13.1611, "lng": 80.3012, "address": "Thiruvottiyur High Road, Chennai"},
    {"zone": "North", "sub_division": "Thiruvottiyur", "station_name": "H7 Peripheral Hospital", "contact_number": "04423452495", "lat": 13.1492, "lng": 80.2954, "address": "Peripheral Hospital, Tondiarpet, Chennai"},
    {"zone": "North", "sub_division": "Thiruvottiyur", "station_name": "H5 New Washermenpet", "contact_number": "04423452490;491", "lat": 13.1205, "lng": 80.2890, "address": "New Washermanpet, Chennai"},
    {"zone": "North", "sub_division": "Royapuram", "station_name": "N1 Royapuram", "contact_number": "04423452504;505", "lat": 13.1042, "lng": 80.2946, "address": "Royapuram, Chennai"},
    {"zone": "North", "sub_division": "Royapuram", "station_name": "N2 Kasimedu", "contact_number": "04423452511;510", "lat": 13.1256, "lng": 80.2978, "address": "Kasimedu, Chennai"},
    {"zone": "North", "sub_division": "Royapuram", "station_name": "N4 Fishing Harbour", "contact_number": "04423452517;518", "lat": 13.1221, "lng": 80.3005, "address": "Fishing Harbour, Kasimedu, Chennai"},
    {"zone": "North", "sub_division": "Madhavaram", "station_name": "M1 Madhavaram", "contact_number": "04423452783", "lat": 13.1489, "lng": 80.2314, "address": "Madhavaram, Chennai"},
    {"zone": "North", "sub_division": "Madhavaram", "station_name": "M2 Milk Colony", "contact_number": "04425555085", "lat": 13.1534, "lng": 80.2456, "address": "Madhavaram Milk Colony, Chennai"},
    {"zone": "North", "sub_division": "Puzhal", "station_name": "M3 Puzhal", "contact_number": "04426590989", "lat": 13.1678, "lng": 80.1989, "address": "Puzhal, Chennai"},
    {"zone": "North", "sub_division": "Puzhal", "station_name": "M4 Redhills", "contact_number": "04426418296", "lat": 13.1972, "lng": 80.1945, "address": "Redhills, Chennai"},
    {"zone": "North", "sub_division": "Ennore", "station_name": "M5 Ennore", "contact_number": "04425750237", "lat": 13.2145, "lng": 80.3214, "address": "Ennore High Road, Chennai"},
    {"zone": "North", "sub_division": "Ennore", "station_name": "M6 Manali", "contact_number": "04423452788", "lat": 13.1689, "lng": 80.2612, "address": "Manali, Chennai"},
    {"zone": "North", "sub_division": "Ennore", "station_name": "M7 Manali New Town", "contact_number": "04425931299", "lat": 13.1894, "lng": 80.2745, "address": "Manali New Town, Chennai"},
    {"zone": "North", "sub_division": "Ennore", "station_name": "M8 Sathangadu", "contact_number": "04423452790", "lat": 13.1567, "lng": 80.2789, "address": "Sathangadu, Chennai"},

    # West Zone
    {"zone": "West", "sub_division": "Pulianthope", "station_name": "P1 Pulianthope", "contact_number": "04423452520;521", "lat": 13.0978, "lng": 80.2667, "address": "Pulianthope, Chennai"},
    {"zone": "West", "sub_division": "Pulianthope", "station_name": "P2 Otteri", "contact_number": "04423452524;525", "lat": 13.0934, "lng": 80.2545, "address": "Otteri, Chennai"},
    {"zone": "West", "sub_division": "Pulianthope", "station_name": "P4 Basin Bridge", "contact_number": "04426670948", "lat": 13.0998, "lng": 80.2734, "address": "Basin Bridge, Chennai"},
    {"zone": "West", "sub_division": "MKB Nagar", "station_name": "P5 MKB Nagar", "contact_number": "04423452531;532", "lat": 13.1189, "lng": 80.2589, "address": "MKB Nagar, Vyasarpadi, Chennai"},
    {"zone": "West", "sub_division": "MKB Nagar", "station_name": "P6 Kodungaiyur", "contact_number": "04425546241", "lat": 13.1367, "lng": 80.2678, "address": "Kodungaiyur, Chennai"},
    {"zone": "West", "sub_division": "MKB Nagar", "station_name": "P3 Vyasarpadi", "contact_number": "04423452527;526", "lat": 13.1112, "lng": 80.2612, "address": "Vyasarpadi, Chennai"},
    {"zone": "West", "sub_division": "Sembium", "station_name": "K1 Sembium", "contact_number": "04423452710;711", "lat": 13.1178, "lng": 80.2378, "address": "Sembium, Perambur, Chennai"},
    {"zone": "West", "sub_division": "Sembium", "station_name": "K5 Peravallur", "contact_number": "04423452727;728", "lat": 13.1134, "lng": 80.2289, "address": "Peravallur, Chennai"},
    {"zone": "West", "sub_division": "Sembium", "station_name": "K9 Thiru vi ka Nagar", "contact_number": "04423452736;737", "lat": 13.1198, "lng": 80.2345, "address": "Thiru Vi Ka Nagar, Chennai"},
    {"zone": "West", "sub_division": "Anna Nagar", "station_name": "K3 Aminjikarai", "contact_number": "04423452716;717", "lat": 13.0723, "lng": 80.2212, "address": "Aminjikarai, Chennai"},
    {"zone": "West", "sub_division": "Anna Nagar", "station_name": "K4 Anna Nagar", "contact_number": "04423452719;720", "lat": 13.0856, "lng": 80.2145, "address": "Anna Nagar Roundtana, Chennai"},
    {"zone": "West", "sub_division": "Anna Nagar", "station_name": "K8 Arumbakkam", "contact_number": "04423452733", "lat": 13.0678, "lng": 80.2089, "address": "Arumbakkam, Chennai"},
    {"zone": "West", "sub_division": "Thirumangalam", "station_name": "V3 J J Nagar", "contact_number": "04423452748;749", "lat": 13.0812, "lng": 80.1945, "address": "JJ Nagar, Mogappair, Chennai"},
    {"zone": "West", "sub_division": "Thirumangalam", "station_name": "V5 Thirumangalam", "contact_number": "04423452753;754", "lat": 13.0854, "lng": 80.1998, "address": "Thirumangalam Junction, Chennai"},
    {"zone": "West", "sub_division": "Thirumangalam", "station_name": "V7 Nolambur", "contact_number": "9940596447", "lat": 13.0778, "lng": 80.1745, "address": "Nolambur, Chennai"},
    {"zone": "West", "sub_division": "Koyambedu", "station_name": "K10 Koyambedu", "contact_number": "04423452739", "lat": 13.0698, "lng": 80.1945, "address": "Koyambedu Market, Chennai"},
    {"zone": "West", "sub_division": "Koyambedu", "station_name": "T4 Maduravoyal", "contact_number": "04423452766", "lat": 13.0634, "lng": 80.1654, "address": "Maduravoyal, Chennai"},
    {"zone": "West", "sub_division": "Koyambedu", "station_name": "CMBT", "contact_number": "9677099958", "lat": 13.0672, "lng": 80.2034, "address": "CMBT Bus Terminus, Chennai"},
    {"zone": "West", "sub_division": "Villivakkam", "station_name": "V1 Villivakkam", "contact_number": "04423452744;745", "lat": 13.1078, "lng": 80.2089, "address": "Villivakkam, Chennai"},
    {"zone": "West", "sub_division": "Villivakkam", "station_name": "V4 Rajamangalam", "contact_number": "04423452750;751", "lat": 13.1145, "lng": 80.2012, "address": "Rajamangalam, Villivakkam, Chennai"},
    {"zone": "West", "sub_division": "Villivakkam", "station_name": "V6 Kolathur", "contact_number": "04423452758", "lat": 13.1256, "lng": 80.2178, "address": "Kolathur, Chennai"},
    {"zone": "West", "sub_division": "Ambattur", "station_name": "T1 Ambattur", "contact_number": "04423452797", "lat": 13.1145, "lng": 80.1545, "address": "Ambattur OT, Chennai"},
    {"zone": "West", "sub_division": "Ambattur", "station_name": "T2 Ambattur Estate", "contact_number": "04423452798", "lat": 13.0945, "lng": 80.1678, "address": "Ambattur Industrial Estate, Chennai"},
    {"zone": "West", "sub_division": "Ambattur", "station_name": "T3 Korattur", "contact_number": "04423452799", "lat": 13.1098, "lng": 80.1834, "address": "Korattur, Chennai"},
    {"zone": "West", "sub_division": "Avadi", "station_name": "T6 Avadi", "contact_number": "04426554750", "lat": 13.1189, "lng": 80.1012, "address": "Avadi, Chennai"},
    {"zone": "West", "sub_division": "Avadi", "station_name": "T7 Tank Factory", "contact_number": "04423452771", "lat": 13.1345, "lng": 80.0945, "address": "HVF Estate, Avadi, Chennai"},
    {"zone": "West", "sub_division": "Avadi", "station_name": "T10 Thirumullaivoyal", "contact_number": "04423452772", "lat": 13.1289, "lng": 80.1345, "address": "Thirumullaivoyal, Chennai"},
    {"zone": "West", "sub_division": "Pattabiram", "station_name": "T11 Thirunindravur", "contact_number": "4426390293", "lat": 13.1178, "lng": 80.0345, "address": "Thirunindravur, Chennai"},
    {"zone": "West", "sub_division": "Pattabiram", "station_name": "T8 Muthapudupet", "contact_number": "044 26841795", "lat": 13.1512, "lng": 80.0812, "address": "Muthapudupet, Avadi IAF, Chennai"},
    {"zone": "West", "sub_division": "Pattabiram", "station_name": "T9 Pattabiram", "contact_number": "044  26851632", "lat": 13.1234, "lng": 80.0612, "address": "Pattabiram, Chennai"},
    {"zone": "West", "sub_division": "Poonamallee", "station_name": "T12 Poonamallee", "contact_number": "04426272082", "lat": 13.0489, "lng": 80.1089, "address": "Poonamallee Trunk Road, Chennai"},
    {"zone": "West", "sub_division": "Poonamallee", "station_name": "T16 Nasaratpet", "contact_number": "04426271414", "lat": 13.0534, "lng": 80.0789, "address": "Nazarathpet, Chennai"},
    {"zone": "West", "sub_division": "Poonamallee", "station_name": "T5 Thiruverkadu", "contact_number": "04426800091", "lat": 13.0712, "lng": 80.1245, "address": "Thiruverkadu, Chennai"},
    {"zone": "West", "sub_division": "SRMC", "station_name": "T15 SRMC", "contact_number": "04423452767", "lat": 13.0378, "lng": 80.1456, "address": "SRMC Porur, Chennai"},
    {"zone": "West", "sub_division": "SRMC", "station_name": "T14 Mangadu", "contact_number": "04426791102", "lat": 13.0234, "lng": 80.1212, "address": "Mangadu, Chennai"},
    {"zone": "West", "sub_division": "SRMC", "station_name": "T13 Kunrathur", "contact_number": "04424780039", "lat": 12.9978, "lng": 80.0989, "address": "Kundrathur, Chennai"},

    # East / Central Zone
    {"zone": "East; Central", "sub_division": "Kilpauk", "station_name": "K6 TP Chathiram", "contact_number": "04423452729;730", "lat": 13.0789, "lng": 80.2378, "address": "TP Chatram, Kilpauk, Chennai"},
    {"zone": "East; Central", "sub_division": "Kilpauk", "station_name": "G3 Kilpauk", "contact_number": "04423452699;700", "lat": 13.0812, "lng": 80.2456, "address": "Kilpauk Garden Road, Chennai"},
    {"zone": "East; Central", "sub_division": "Kilpauk", "station_name": "G7 Chetpet", "contact_number": "04423452686", "lat": 13.0712, "lng": 80.2434, "address": "Chetpet, Chennai"},
    {"zone": "East; Central", "sub_division": "Kilpauk", "station_name": "G6 KMC Hospital", "contact_number": "04423452709", "lat": 13.0798, "lng": 80.2478, "address": "KMC Hospital, Poonamallee High Rd, Chennai"},
    {"zone": "East; Central", "sub_division": "Vepery", "station_name": "G1 Vepery", "contact_number": "04423452690;691", "lat": 13.0878, "lng": 80.2612, "address": "EVK Sampath Salai, Vepery, Chennai"},
    {"zone": "East; Central", "sub_division": "Vepery", "station_name": "G2 Periamet", "contact_number": "04423452696;6 97", "lat": 13.0834, "lng": 80.2712, "address": "Periamet, Chennai"},
    {"zone": "East; Central", "sub_division": "Ayanavaram", "station_name": "K2 Ayanavaram", "contact_number": "04423452714;715", "lat": 13.0978, "lng": 80.2312, "address": "Ayanavaram, Chennai"},
    {"zone": "East; Central", "sub_division": "Ayanavaram", "station_name": "K7 ICF", "contact_number": "04423452731;732", "lat": 13.0945, "lng": 80.2178, "address": "ICF Colony, Villivakkam, Chennai"},
    {"zone": "East; Central", "sub_division": "Ayanavaram", "station_name": "G4 Mental Hospital", "contact_number": "NA", "lat": 13.0912, "lng": 80.2389, "address": "Institute of Mental Health, Kilpauk, Chennai"},
    {"zone": "East; Central", "sub_division": "Ayanavaram", "station_name": "G5 Secretariat Colony", "contact_number": "04423452704;706", "lat": 13.0889, "lng": 80.2456, "address": "Secretariat Colony, Kilpauk, Chennai"},
    {"zone": "East; Central", "sub_division": "Triplicane", "station_name": "D1 Triplicane", "contact_number": "04423452655;656", "lat": 13.0589, "lng": 80.2756, "address": "Triplicane High Road, Chennai"},
    {"zone": "East; Central", "sub_division": "Triplicane", "station_name": "D8 K G Hospital", "contact_number": "04423452672", "lat": 13.0534, "lng": 80.2789, "address": "Kasturba Gandhi Hospital, Triplicane, Chennai"},
    {"zone": "East; Central", "sub_division": "Triplicane", "station_name": "D2 Annasalai", "contact_number": "04423452661;662", "lat": 13.0645, "lng": 80.2678, "address": "Anna Salai, Triplicane, Chennai"},
    {"zone": "East; Central", "sub_division": "Triplicane", "station_name": "D4 Zam Bazaar", "contact_number": "04423452665;666", "lat": 13.0556, "lng": 80.2689, "address": "Zam Bazaar, Triplicane, Chennai"},
    {"zone": "East; Central", "sub_division": "Triplicane", "station_name": "D6 Anna Square", "contact_number": "04423452667;668", "lat": 13.0645, "lng": 80.2834, "address": "Marina Beach Promenade, Anna Square, Chennai"},
    {"zone": "East; Central", "sub_division": "Egmore", "station_name": "F1 Chintadaripet", "contact_number": "04423452673;674", "lat": 13.0756, "lng": 80.2734, "address": "Chintadripet, Chennai"},
    {"zone": "East; Central", "sub_division": "Egmore", "station_name": "F2 Egmore", "contact_number": "04423452677;678", "lat": 13.0789, "lng": 80.2612, "address": "Egmore High Road, Chennai"},
    {"zone": "East; Central", "sub_division": "Egmore", "station_name": "F7 Maternity Hospital", "contact_number": "04423452689", "lat": 13.0712, "lng": 80.2601, "address": "Govt Maternity Hospital, Egmore, Chennai"},
    {"zone": "East; Central", "sub_division": "Nungambakkam", "station_name": "F3 Nungambakkam", "contact_number": "04423452680;681", "lat": 13.0612, "lng": 80.2456, "address": "Nungambakkam High Road, Chennai"},
    {"zone": "East; Central", "sub_division": "Nungambakkam", "station_name": "F4 Thousand Lights", "contact_number": "04423452684;683", "lat": 13.0567, "lng": 80.2545, "address": "Greams Road, Thousand Lights, Chennai"},
    {"zone": "East; Central", "sub_division": "Nungambakkam", "station_name": "R5 Choolaimedu", "contact_number": "04423452742;743", "lat": 13.0612, "lng": 80.2245, "address": "Choolaimedu High Road, Chennai"},
    {"zone": "East; Central", "sub_division": "Mylapore", "station_name": "E1 Mylapore", "contact_number": "04423452562", "lat": 13.0367, "lng": 80.2678, "address": "Kutchery Road, Mylapore, Chennai"},
    {"zone": "East; Central", "sub_division": "Mylapore", "station_name": "E5 Foreshore Estate", "contact_number": "04423452575", "lat": 13.0289, "lng": 80.2789, "address": "Foreshore Estate, Santhome, Chennai"},
    {"zone": "East; Central", "sub_division": "Mylapore", "station_name": "D5 Marina", "contact_number": "04423452558;559", "lat": 13.0456, "lng": 80.2801, "address": "Kamarajar Salai, Marina Beach, Chennai"},
    {"zone": "East; Central", "sub_division": "Kotturpuram", "station_name": "E4 Abiramapuram", "contact_number": "04423452571;572", "lat": 13.0334, "lng": 80.2512, "address": "Abiramapuram, Chennai"},
    {"zone": "East; Central", "sub_division": "Kotturpuram", "station_name": "J2 Kotturpuram", "contact_number": "04423452595;596", "lat": 13.0212, "lng": 80.2445, "address": "Gandhi Mandapam Road, Kotturpuram, Chennai"},
    {"zone": "East; Central", "sub_division": "Royapettah", "station_name": "E2 Royapettah", "contact_number": "04423452567;565", "lat": 13.0512, "lng": 80.2612, "address": "Royapettah High Road, Chennai"},
    {"zone": "East; Central", "sub_division": "Royapettah", "station_name": "D3 Ice House", "contact_number": "04423452556;555", "lat": 13.0512, "lng": 80.2734, "address": "Ice House, Triplicane, Chennai"},
    {"zone": "East; Central", "sub_division": "Royapettah", "station_name": "E6 Govt. Royapettah", "contact_number": "04423452576", "lat": 13.0534, "lng": 80.2589, "address": "Govt Royapettah Hospital, Chennai"},

    # South Zone
    {"zone": "South", "sub_division": "St Thomas Mount", "station_name": "S1 St Thomas Mount", "contact_number": "04423452763", "lat": 13.0034, "lng": 80.1989, "address": "St. Thomas Mount, Chennai"},
    {"zone": "South", "sub_division": "St Thomas Mount", "station_name": "S4 Nandampakkam", "contact_number": "04423452765", "lat": 13.0112, "lng": 80.1789, "address": "Nandambakkam, Chennai"},
    {"zone": "South", "sub_division": "St Thomas Mount", "station_name": "S9 Palavanthangal", "contact_number": "04422241950", "lat": 12.9878, "lng": 80.1878, "address": "Pazhavanthangal, Chennai"},
    {"zone": "South", "sub_division": "Meenambakkam", "station_name": "S2 Airport", "contact_number": "04422564284", "lat": 12.9856, "lng": 80.1698, "address": "Chennai International Airport, Meenambakkam"},
    {"zone": "South", "sub_division": "Meenambakkam", "station_name": "S3 Meenambakkam", "contact_number": "04422561261", "lat": 12.9812, "lng": 80.1756, "address": "GST Road, Meenambakkam, Chennai"},
    {"zone": "South", "sub_division": "Pallavaram", "station_name": "S5 Pallavaram", "contact_number": "04422640880", "lat": 12.9678, "lng": 80.1489, "address": "Pallavaram, Chennai"},
    {"zone": "South", "sub_division": "Pallavaram", "station_name": "S6 Sankar Nagar", "contact_number": "04422484094", "lat": 12.9512, "lng": 80.1345, "address": "Sankar Nagar, Pammal, Chennai"},
    {"zone": "South", "sub_division": "Tambaram", "station_name": "S11 Tambaram", "contact_number": "04423452769", "lat": 12.9245, "lng": 80.1278, "address": "Tambaram Sanatorium / West Tambaram, Chennai"},
    {"zone": "South", "sub_division": "Tambaram", "station_name": "S13 Chrompet", "contact_number": "04423452770", "lat": 12.9512, "lng": 80.1412, "address": "Chromepet, GST Road, Chennai"},
    {"zone": "South", "sub_division": "Selaiyur", "station_name": "S15 Selaiyur", "contact_number": "04422396003", "lat": 12.9189, "lng": 80.1456, "address": "Selaiyur, East Tambaram, Chennai"},
    {"zone": "South", "sub_division": "Selaiyur", "station_name": "S12 Chitlapakkam", "contact_number": "04422232005", "lat": 12.9378, "lng": 80.1489, "address": "Chitlapakkam, Chennai"},
    {"zone": "South", "sub_division": "Selaiyur", "station_name": "S14 Peerkankaranai", "contact_number": "04422398018", "lat": 12.9056, "lng": 80.0989, "address": "Peerkankaranai, New Perungalathur, Chennai"},
    {"zone": "South", "sub_division": "Madipakkam", "station_name": "S7 Madipakkam", "contact_number": "04423452774", "lat": 12.9645, "lng": 80.1989, "address": "Madipakkam Main Road, Chennai"},
    {"zone": "South", "sub_division": "Madipakkam", "station_name": "S8 Adambakkam", "contact_number": "04423452777", "lat": 12.9889, "lng": 80.2034, "address": "Adambakkam, Chennai"},
    {"zone": "South", "sub_division": "Madipakkam", "station_name": "S10 Pallikaranai", "contact_number": "04423452775", "lat": 12.9345, "lng": 80.2145, "address": "Pallikaranai, Chennai"},
    {"zone": "South", "sub_division": "Adyar", "station_name": "J2 Adyar", "contact_number": "04423452583;584", "lat": 13.0067, "lng": 80.2567, "address": "Sardar Patel Road, Adyar, Chennai"},
    {"zone": "South", "sub_division": "Adyar", "station_name": "J5 Sastri Nagar", "contact_number": "04423452598;599", "lat": 12.9989, "lng": 80.2612, "address": "Shastri Nagar, Adyar, Chennai"},
    {"zone": "South", "sub_division": "Saidapet", "station_name": "J1 Saidapet", "contact_number": "04423452577;578", "lat": 13.0212, "lng": 80.2234, "address": "Anna Salai, Saidapet, Chennai"},
    {"zone": "South", "sub_division": "Saidapet", "station_name": "R6 Kumaran Nagar", "contact_number": "04423452629;628", "lat": 13.0312, "lng": 80.2145, "address": "Kumaran Nagar, Saidapet, Chennai"},
    {"zone": "South", "sub_division": "Guindy", "station_name": "J3 Guindy", "contact_number": "04423452590;591", "lat": 13.0078, "lng": 80.2134, "address": "Guindy Railway Station / GST Road, Chennai"},
    {"zone": "South", "sub_division": "Guindy", "station_name": "J7 Velachery", "contact_number": "04423452605;606", "lat": 12.9812, "lng": 80.2212, "address": "Velachery Bypass Road, Chennai"},
    {"zone": "South", "sub_division": "Taramani", "station_name": "J6 Thiruvanmiyur", "contact_number": "04423452602;603", "lat": 12.9878, "lng": 80.2589, "address": "LB Road, Thiruvanmiyur, Chennai"},
    {"zone": "South", "sub_division": "Taramani", "station_name": "J13 Taramani", "contact_number": "04422541636", "lat": 12.9789, "lng": 80.2434, "address": "CSIR Road, Taramani, Chennai"},
    {"zone": "South", "sub_division": "Thuraipakkam", "station_name": "J9 Thoraipakkam", "contact_number": "04423452776", "lat": 12.9412, "lng": 80.2378, "address": "OMR, Thoraipakkam, Chennai"},
    {"zone": "South", "sub_division": "Thuraipakkam", "station_name": "J10 Chemmanchery", "contact_number": "04424500707", "lat": 12.8712, "lng": 80.2267, "address": "Chemmanchery, OMR, Chennai"},
    {"zone": "South", "sub_division": "Thuraipakkam", "station_name": "J11 Kannagi Nagar", "contact_number": "9791090918", "lat": 12.9312, "lng": 80.2345, "address": "Kannagi Nagar, Thoraipakkam, Chennai"},
    {"zone": "South", "sub_division": "Neelangari", "station_name": "J8 Neelangari", "contact_number": "04424491196", "lat": 12.9489, "lng": 80.2589, "address": "ECR, Neelankarai, Chennai"},
    {"zone": "South", "sub_division": "Neelangari", "station_name": "J12 Kannathur", "contact_number": "04427472182", "lat": 12.8612, "lng": 80.2456, "address": "ECR, Kanathur, Chennai"},
    {"zone": "South", "sub_division": "T.Nagar", "station_name": "R1 Mambalam", "contact_number": "04423452608;609", "lat": 13.0378, "lng": 80.2289, "address": "Station Road, West Mambalam, Chennai"},
    {"zone": "South", "sub_division": "T.Nagar", "station_name": "R4 Soundarapandiyanar", "contact_number": "04423452624", "lat": 13.0412, "lng": 80.2345, "address": "Panagal Park, T. Nagar, Chennai"},
    {"zone": "South", "sub_division": "T.Nagar", "station_name": "R4 Pondy Bazaar L&O", "contact_number": "04423452624;625", "lat": 13.0423, "lng": 80.2389, "address": "Pondy Bazaar, T. Nagar, Chennai"},
    {"zone": "South", "sub_division": "Vadapalani", "station_name": "R8 Vadapalani", "contact_number": "04423452635;634", "lat": 13.0512, "lng": 80.2112, "address": "Arcot Road, Vadapalani, Chennai"},
    {"zone": "South", "sub_division": "Vadapalani", "station_name": "R5 Virugambakkam", "contact_number": "04423452637;638", "lat": 13.0489, "lng": 80.1945, "address": "Arcot Road, Virugambakkam, Chennai"},
    {"zone": "South", "sub_division": "Valasaravakkam", "station_name": "R9 Valasaravakkam", "contact_number": "04423452649", "lat": 13.0412, "lng": 80.1789, "address": "Arcot Road, Valasaravakkam, Chennai"},
    {"zone": "South", "sub_division": "Valasaravakkam", "station_name": "R11 Royala nagar", "contact_number": "04423452649", "lat": 13.0312, "lng": 80.1834, "address": "Royala Nagar, Ramapuram, Chennai"},
    {"zone": "South", "sub_division": "Ashok Nagar", "station_name": "R3 Ashok Nagar", "contact_number": "04423452617;618", "lat": 13.0367, "lng": 80.2189, "address": "Ashok Pillar, Ashok Nagar, Chennai"},
    {"zone": "South", "sub_division": "Ashok Nagar", "station_name": "R7 K K Nagar", "contact_number": "04423452630;631", "lat": 13.0389, "lng": 80.1989, "address": "KK Nagar, Chennai"},
    {"zone": "South", "sub_division": "Ashok Nagar", "station_name": "R10 MGR Nagar", "contact_number": "04423452560;561", "lat": 13.0289, "lng": 80.2034, "address": "MGR Nagar, KK Nagar, Chennai"},
    {"zone": "South", "sub_division": "Teynampet", "station_name": "E3 Teynampet", "contact_number": "04423452569;568", "lat": 13.0412, "lng": 80.2512, "address": "Anna Salai, Teynampet, Chennai"},
    {"zone": "South", "sub_division": "Teynampet", "station_name": "R2 Kodambakkam", "contact_number": "04423452615;616", "lat": 13.0512, "lng": 80.2245, "address": "Kodambakkam High Road, Chennai"},
]

# ─── 2. CHENNAI SAFETY ZONES DATASET (56 ZONES CHN001 - CHN056) ─────────────
CHENNAI_SAFETY_ZONES_DATA = [
    {
        "id": "CHN001", "place": "Adyar", "category": "Central & Premium", "anchor_area": "Adyar",
        "demo_safety_label": "highly_safe", "day_risk_score": 18, "night_risk_score": 10, "route_risk_score": 12,
        "footfall": "High", "night_activity": "Low", "lighting": "High", "isolation": "Low",
        "recommendation": "Main roads preferred", "demo_safety_score": 88,
        "lat": 13.0067, "lng": 80.2567, "radius_meters": 600.0,
        "geocode_query": "Adyar, Chennai, Tamil Nadu, India"
    },
    {
        "id": "CHN002", "place": "Gandhi Nagar", "category": "Neighbour of Adyar", "anchor_area": "Adyar",
        "demo_safety_label": "highly_safe", "day_risk_score": 20, "night_risk_score": 12, "route_risk_score": 14,
        "footfall": "High", "night_activity": "Low", "lighting": "High", "isolation": "Low",
        "recommendation": "Well-lit/main roads preferred", "demo_safety_score": 86,
        "lat": 13.0102, "lng": 80.2534, "radius_meters": 500.0,
        "geocode_query": "Gandhi Nagar, Chennai, Tamil Nadu, India"
    },
    {
        "id": "CHN003", "place": "Kasturba Nagar", "category": "Neighbour of Adyar", "anchor_area": "Adyar",
        "demo_safety_label": "safe", "day_risk_score": 24, "night_risk_score": 16, "route_risk_score": 19,
        "footfall": "High", "night_activity": "Low", "lighting": "High", "isolation": "Low",
        "recommendation": "Prefer main roads late night", "demo_safety_score": 81,
        "lat": 13.0034, "lng": 80.2512, "radius_meters": 500.0,
        "geocode_query": "Kasturba Nagar, Chennai, Tamil Nadu, India"
    },
    {
        "id": "CHN004", "place": "Kotturpuram", "category": "Neighbour of Adyar", "anchor_area": "Adyar",
        "demo_safety_label": "safe", "day_risk_score": 28, "night_risk_score": 22, "route_risk_score": 25,
        "footfall": "High", "night_activity": "Low", "lighting": "High", "isolation": "Low",
        "recommendation": "Prefer populated roads", "demo_safety_score": 75,
        "lat": 13.0189, "lng": 80.2412, "radius_meters": 600.0,
        "geocode_query": "Kotturpuram, Chennai, Tamil Nadu, India"
    },
    {
        "id": "CHN005", "place": "Besant Nagar", "category": "Central & Premium", "anchor_area": "Besant Nagar",
        "demo_safety_label": "highly_safe", "day_risk_score": 22, "night_risk_score": 14, "route_risk_score": 18,
        "footfall": "High", "night_activity": "Low", "lighting": "High", "isolation": "Low",
        "recommendation": "Avoid isolated beach stretches late night", "demo_safety_score": 82,
        "lat": 13.0001, "lng": 80.2667, "radius_meters": 600.0,
        "geocode_query": "Besant Nagar, Chennai, Tamil Nadu, India"
    },
    {
        "id": "CHN006", "place": "Elliots Beach Periphery", "category": "Neighbour of Besant Nagar", "anchor_area": "Besant Nagar",
        "demo_safety_label": "caution_at_night", "day_risk_score": 48, "night_risk_score": 78, "route_risk_score": 63,
        "footfall": "Medium", "night_activity": "Medium", "lighting": "Medium", "isolation": "High",
        "recommendation": "Prefer main avenue after dark", "demo_safety_score": 37,
        "lat": 12.9978, "lng": 80.2734, "radius_meters": 550.0,
        "geocode_query": "Elliots Beach Periphery, Chennai, Tamil Nadu, India"
    },
    {
        "id": "CHN007", "place": "Mylapore", "category": "Central & Premium", "anchor_area": "Mylapore",
        "demo_safety_label": "highly_safe", "day_risk_score": 24, "night_risk_score": 42, "route_risk_score": 33,
        "footfall": "High", "night_activity": "Low", "lighting": "High", "isolation": "Medium",
        "recommendation": "Avoid deserted inner lanes late night", "demo_safety_score": 67,
        "lat": 13.0367, "lng": 80.2678, "radius_meters": 650.0,
        "geocode_query": "Mylapore, Chennai, Tamil Nadu, India"
    },
    {
        "id": "CHN008", "place": "Alwarpet", "category": "Neighbour of Mylapore", "anchor_area": "Mylapore",
        "demo_safety_label": "safe", "day_risk_score": 26, "night_risk_score": 35, "route_risk_score": 31,
        "footfall": "High", "night_activity": "Low", "lighting": "High", "isolation": "Low",
        "recommendation": "Prefer active roads", "demo_safety_score": 69,
        "lat": 13.0334, "lng": 80.2545, "radius_meters": 550.0,
        "geocode_query": "Alwarpet, Chennai, Tamil Nadu, India"
    },
    {
        "id": "CHN009", "place": "R.A. Puram", "category": "Neighbour of Mylapore", "anchor_area": "Mylapore",
        "demo_safety_label": "safe", "day_risk_score": 25, "night_risk_score": 32, "route_risk_score": 29,
        "footfall": "High", "night_activity": "Low", "lighting": "High", "isolation": "Low",
        "recommendation": "Prefer main roads", "demo_safety_score": 71,
        "lat": 13.0256, "lng": 80.2589, "radius_meters": 550.0,
        "geocode_query": "R.A. Puram, Chennai, Tamil Nadu, India"
    },
    {
        "id": "CHN010", "place": "Nungambakkam", "category": "Central & Premium", "anchor_area": "Nungambakkam",
        "demo_safety_label": "safe", "day_risk_score": 28, "night_risk_score": 38, "route_risk_score": 33,
        "footfall": "High", "night_activity": "Low", "lighting": "High", "isolation": "Medium",
        "recommendation": "Prefer active commercial corridors", "demo_safety_score": 67,
        "lat": 13.0612, "lng": 80.2456, "radius_meters": 650.0,
        "geocode_query": "Nungambakkam, Chennai, Tamil Nadu, India"
    },
    {
        "id": "CHN011", "place": "T. Nagar", "category": "Central & Premium", "anchor_area": "T. Nagar",
        "demo_safety_label": "safe", "day_risk_score": 36, "night_risk_score": 52, "route_risk_score": 44,
        "footfall": "High", "night_activity": "Medium", "lighting": "High", "isolation": "Medium",
        "recommendation": "Watch belongings in crowds; prefer main roads", "demo_safety_score": 56,
        "lat": 13.0412, "lng": 80.2345, "radius_meters": 700.0,
        "geocode_query": "T. Nagar, Chennai, Tamil Nadu, India"
    },
    {
        "id": "CHN012", "place": "West Mambalam", "category": "Neighbour of T. Nagar", "anchor_area": "T. Nagar",
        "demo_safety_label": "safe", "day_risk_score": 30, "night_risk_score": 45, "route_risk_score": 38,
        "footfall": "High", "night_activity": "Low", "lighting": "High", "isolation": "Medium",
        "recommendation": "Use populated roads", "demo_safety_score": 62,
        "lat": 13.0378, "lng": 80.2234, "radius_meters": 550.0,
        "geocode_query": "West Mambalam, Chennai, Tamil Nadu, India"
    },
    {
        "id": "CHN013", "place": "Saidapet", "category": "Central / Transit", "anchor_area": "Saidapet",
        "demo_safety_label": "moderately_safe", "day_risk_score": 44, "night_risk_score": 60, "route_risk_score": 52,
        "footfall": "Medium", "night_activity": "Medium", "lighting": "Medium", "isolation": "High",
        "recommendation": "Prefer main roads and transit hubs", "demo_safety_score": 48,
        "lat": 13.0212, "lng": 80.2234, "radius_meters": 600.0,
        "geocode_query": "Saidapet, Chennai, Tamil Nadu, India"
    },
    {
        "id": "CHN014", "place": "Triplicane", "category": "Central & Premium", "anchor_area": "Triplicane",
        "demo_safety_label": "moderately_safe", "day_risk_score": 42, "night_risk_score": 64, "route_risk_score": 53,
        "footfall": "Medium", "night_activity": "Medium", "lighting": "Medium", "isolation": "High",
        "recommendation": "Avoid confusing interior lanes late night", "demo_safety_score": 47,
        "lat": 13.0589, "lng": 80.2756, "radius_meters": 600.0,
        "geocode_query": "Triplicane, Chennai, Tamil Nadu, India"
    },
    {
        "id": "CHN015", "place": "Velachery", "category": "IT & Suburbs", "anchor_area": "Velachery",
        "demo_safety_label": "safe", "day_risk_score": 30, "night_risk_score": 48, "route_risk_score": 39,
        "footfall": "High", "night_activity": "Medium", "lighting": "High", "isolation": "Medium",
        "recommendation": "Avoid isolated/unlit pocket lanes", "demo_safety_score": 61,
        "lat": 12.9812, "lng": 80.2212, "radius_meters": 700.0,
        "geocode_query": "Velachery, Chennai, Tamil Nadu, India"
    },
    {
        "id": "CHN016", "place": "Taramani", "category": "Neighbour of Velachery", "anchor_area": "Velachery",
        "demo_safety_label": "safe", "day_risk_score": 34, "night_risk_score": 50, "route_risk_score": 42,
        "footfall": "High", "night_activity": "Medium", "lighting": "Medium", "isolation": "Medium",
        "recommendation": "Prefer active transit corridors", "demo_safety_score": 58,
        "lat": 12.9789, "lng": 80.2434, "radius_meters": 600.0,
        "geocode_query": "Taramani, Chennai, Tamil Nadu, India"
    },
    {
        "id": "CHN017", "place": "Perungudi", "category": "Neighbour of OMR", "anchor_area": "OMR",
        "demo_safety_label": "safe", "day_risk_score": 32, "night_risk_score": 48, "route_risk_score": 40,
        "footfall": "High", "night_activity": "Medium", "lighting": "Medium", "isolation": "Medium",
        "recommendation": "Prefer main IT corridors", "demo_safety_score": 60,
        "lat": 12.9612, "lng": 80.2434, "radius_meters": 650.0,
        "geocode_query": "Perungudi, Chennai, Tamil Nadu, India"
    },
    {
        "id": "CHN018", "place": "Thoraipakkam", "category": "Neighbour of OMR", "anchor_area": "OMR",
        "demo_safety_label": "safe", "day_risk_score": 34, "night_risk_score": 52, "route_risk_score": 43,
        "footfall": "High", "night_activity": "Medium", "lighting": "Medium", "isolation": "Medium",
        "recommendation": "Avoid isolated link roads", "demo_safety_score": 57,
        "lat": 12.9412, "lng": 80.2378, "radius_meters": 650.0,
        "geocode_query": "Thoraipakkam, Chennai, Tamil Nadu, India"
    },
    {
        "id": "CHN019", "place": "Sholinganallur", "category": "OMR", "anchor_area": "OMR",
        "demo_safety_label": "safe", "day_risk_score": 33, "night_risk_score": 46, "route_risk_score": 39,
        "footfall": "High", "night_activity": "Medium", "lighting": "High", "isolation": "Medium",
        "recommendation": "Prefer major corridors", "demo_safety_score": 61,
        "lat": 12.8989, "lng": 80.2289, "radius_meters": 750.0,
        "geocode_query": "Sholinganallur, Chennai, Tamil Nadu, India"
    },
    {
        "id": "CHN020", "place": "OMR Main Corridor", "category": "IT & Suburbs", "anchor_area": "OMR",
        "demo_safety_label": "safe", "day_risk_score": 28, "night_risk_score": 42, "route_risk_score": 35,
        "footfall": "High", "night_activity": "Low", "lighting": "High", "isolation": "Low",
        "recommendation": "Prefer main highway", "demo_safety_score": 65,
        "lat": 12.9256, "lng": 80.2312, "radius_meters": 800.0,
        "geocode_query": "OMR Main Corridor, Chennai, Tamil Nadu, India"
    },
    {
        "id": "CHN021", "place": "ECR Main Corridor", "category": "IT & Suburbs", "anchor_area": "ECR",
        "demo_safety_label": "moderately_safe", "day_risk_score": 38, "night_risk_score": 62, "route_risk_score": 50,
        "footfall": "Medium", "night_activity": "Medium", "lighting": "Medium", "isolation": "High",
        "recommendation": "Avoid isolated coastal link roads", "demo_safety_score": 50,
        "lat": 12.9034, "lng": 80.2489, "radius_meters": 800.0,
        "geocode_query": "ECR Main Corridor, Chennai, Tamil Nadu, India"
    },
    {
        "id": "CHN022", "place": "Muttukadu", "category": "Neighbour of ECR", "anchor_area": "ECR",
        "demo_safety_label": "caution_at_night", "day_risk_score": 52, "night_risk_score": 78, "route_risk_score": 65,
        "footfall": "Low", "night_activity": "High", "lighting": "Low", "isolation": "High",
        "recommendation": "Avoid isolated beach access after dark", "demo_safety_score": 35,
        "lat": 12.8234, "lng": 80.2412, "radius_meters": 650.0,
        "geocode_query": "Muttukadu, Chennai, Tamil Nadu, India"
    },
    {
        "id": "CHN023", "place": "Kalavakkam", "category": "Neighbour of ECR", "anchor_area": "ECR",
        "demo_safety_label": "caution_at_night", "day_risk_score": 50, "night_risk_score": 72, "route_risk_score": 61,
        "footfall": "Medium", "night_activity": "High", "lighting": "Low", "isolation": "High",
        "recommendation": "Prefer populated highway sections", "demo_safety_score": 39,
        "lat": 12.7812, "lng": 80.2189, "radius_meters": 600.0,
        "geocode_query": "Kalavakkam, Chennai, Tamil Nadu, India"
    },
    {
        "id": "CHN024", "place": "Tambaram", "category": "IT & Suburbs", "anchor_area": "Tambaram",
        "demo_safety_label": "safe", "day_risk_score": 34, "night_risk_score": 50, "route_risk_score": 42,
        "footfall": "High", "night_activity": "Medium", "lighting": "High", "isolation": "Medium",
        "recommendation": "Prefer busy transit corridors", "demo_safety_score": 58,
        "lat": 12.9245, "lng": 80.1278, "radius_meters": 750.0,
        "geocode_query": "Tambaram, Chennai, Tamil Nadu, India"
    },
    {
        "id": "CHN025", "place": "Medavakkam", "category": "IT & Suburbs", "anchor_area": "Medavakkam",
        "demo_safety_label": "safe", "day_risk_score": 32, "night_risk_score": 54, "route_risk_score": 43,
        "footfall": "High", "night_activity": "Medium", "lighting": "Medium", "isolation": "Medium",
        "recommendation": "Avoid new isolated layouts at night", "demo_safety_score": 57,
        "lat": 12.9189, "lng": 80.1912, "radius_meters": 650.0,
        "geocode_query": "Medavakkam, Chennai, Tamil Nadu, India"
    },
    {
        "id": "CHN026", "place": "Perumbakkam", "category": "IT & Suburbs", "anchor_area": "Perumbakkam",
        "demo_safety_label": "safe", "day_risk_score": 34, "night_risk_score": 56, "route_risk_score": 45,
        "footfall": "High", "night_activity": "Medium", "lighting": "Medium", "isolation": "Medium",
        "recommendation": "Prefer established main roads", "demo_safety_score": 55,
        "lat": 12.9034, "lng": 80.1989, "radius_meters": 600.0,
        "geocode_query": "Perumbakkam, Chennai, Tamil Nadu, India"
    },
    {
        "id": "CHN027", "place": "Guindy", "category": "Transit & Industrial", "anchor_area": "Guindy",
        "demo_safety_label": "moderately_safe", "day_risk_score": 40, "night_risk_score": 58, "route_risk_score": 49,
        "footfall": "Medium", "night_activity": "Medium", "lighting": "High", "isolation": "Medium",
        "recommendation": "Prefer metro/transit areas", "demo_safety_score": 51,
        "lat": 13.0078, "lng": 80.2134, "radius_meters": 700.0,
        "geocode_query": "Guindy, Chennai, Tamil Nadu, India"
    },
    {
        "id": "CHN028", "place": "Guindy Industrial Estate", "category": "Neighbour of Guindy", "anchor_area": "Guindy",
        "demo_safety_label": "caution_at_night", "day_risk_score": 45, "night_risk_score": 76, "route_risk_score": 61,
        "footfall": "Low", "night_activity": "High", "lighting": "Low", "isolation": "High",
        "recommendation": "Avoid deserted industrial edges late night", "demo_safety_score": 39,
        "lat": 13.0112, "lng": 80.2045, "radius_meters": 650.0,
        "geocode_query": "Guindy Industrial Estate, Chennai, Tamil Nadu, India"
    },
    {
        "id": "CHN029", "place": "Chennai Central Periphery", "category": "Transit & Industrial", "anchor_area": "Chennai Central",
        "demo_safety_label": "moderately_safe", "day_risk_score": 42, "night_risk_score": 66, "route_risk_score": 54,
        "footfall": "High", "night_activity": "Medium", "lighting": "Medium", "isolation": "High",
        "recommendation": "Stay near station/main roads", "demo_safety_score": 46,
        "lat": 13.0827, "lng": 80.2756, "radius_meters": 600.0,
        "geocode_query": "Chennai Central Periphery, Chennai, Tamil Nadu, India"
    },
    {
        "id": "CHN030", "place": "Egmore Station Periphery", "category": "Transit & Industrial", "anchor_area": "Egmore",
        "demo_safety_label": "moderately_safe", "day_risk_score": 40, "night_risk_score": 62, "route_risk_score": 51,
        "footfall": "High", "night_activity": "Medium", "lighting": "Medium", "isolation": "High",
        "recommendation": "Avoid dark outer lanes", "demo_safety_score": 49,
        "lat": 13.0789, "lng": 80.2612, "radius_meters": 600.0,
        "geocode_query": "Egmore Station Periphery, Chennai, Tamil Nadu, India"
    },
    {
        "id": "CHN031", "place": "Perambur", "category": "Transit & Industrial", "anchor_area": "Perambur",
        "demo_safety_label": "moderately_safe", "day_risk_score": 43, "night_risk_score": 68, "route_risk_score": 55,
        "footfall": "Medium", "night_activity": "Medium", "lighting": "Medium", "isolation": "High",
        "recommendation": "Avoid isolated underpasses", "demo_safety_score": 45,
        "lat": 13.1134, "lng": 80.2345, "radius_meters": 650.0,
        "geocode_query": "Perambur, Chennai, Tamil Nadu, India"
    },
    {
        "id": "CHN032", "place": "Perambur Railway Underpass", "category": "Neighbour of Perambur", "anchor_area": "Perambur",
        "demo_safety_label": "caution_at_night", "day_risk_score": 52, "night_risk_score": 78, "route_risk_score": 65,
        "footfall": "Low", "night_activity": "High", "lighting": "Low", "isolation": "High",
        "recommendation": "Use main pedestrian routes", "demo_safety_score": 35,
        "lat": 13.1098, "lng": 80.2389, "radius_meters": 450.0,
        "geocode_query": "Perambur Railway Underpass, Chennai, Tamil Nadu, India"
    },
    {
        "id": "CHN033", "place": "Otteri", "category": "Transit & Industrial", "anchor_area": "Otteri",
        "demo_safety_label": "moderately_safe", "day_risk_score": 45, "night_risk_score": 65, "route_risk_score": 55,
        "footfall": "Medium", "night_activity": "Medium", "lighting": "Medium", "isolation": "High",
        "recommendation": "Prefer active roads", "demo_safety_score": 45,
        "lat": 13.0934, "lng": 80.2545, "radius_meters": 550.0,
        "geocode_query": "Otteri, Chennai, Tamil Nadu, India"
    },
    {
        "id": "CHN034", "place": "Padi", "category": "Transit & Industrial", "anchor_area": "Padi",
        "demo_safety_label": "moderately_safe", "day_risk_score": 42, "night_risk_score": 68, "route_risk_score": 55,
        "footfall": "Medium", "night_activity": "High", "lighting": "Low", "isolation": "High",
        "recommendation": "Avoid low-footfall industrial edges", "demo_safety_score": 45,
        "lat": 13.1012, "lng": 80.1834, "radius_meters": 600.0,
        "geocode_query": "Padi, Chennai, Tamil Nadu, India"
    },
    {
        "id": "CHN035", "place": "Kasimedu", "category": "Northern & Peripheral", "anchor_area": "Kasimedu",
        "demo_safety_label": "caution_advised", "day_risk_score": 58, "night_risk_score": 78, "route_risk_score": 68,
        "footfall": "Low", "night_activity": "High", "lighting": "Low", "isolation": "High",
        "recommendation": "Avoid solo travel after dusk", "demo_safety_score": 32,
        "lat": 13.1256, "lng": 80.2978, "radius_meters": 600.0,
        "geocode_query": "Kasimedu, Chennai, Tamil Nadu, India"
    },
    {
        "id": "CHN036", "place": "Royapuram", "category": "Northern & Peripheral", "anchor_area": "Royapuram",
        "demo_safety_label": "moderately_safe", "day_risk_score": 46, "night_risk_score": 65, "route_risk_score": 56,
        "footfall": "Medium", "night_activity": "Medium", "lighting": "Medium", "isolation": "High",
        "recommendation": "Prefer main roads at night", "demo_safety_score": 44,
        "lat": 13.1042, "lng": 80.2946, "radius_meters": 600.0,
        "geocode_query": "Royapuram, Chennai, Tamil Nadu, India"
    },
    {
        "id": "CHN037", "place": "Vyasarpadi", "category": "Northern & Peripheral", "anchor_area": "Vyasarpadi",
        "demo_safety_label": "caution_advised", "day_risk_score": 55, "night_risk_score": 76, "route_risk_score": 66,
        "footfall": "Low", "night_activity": "High", "lighting": "Low", "isolation": "High",
        "recommendation": "Prefer populated routes", "demo_safety_score": 34,
        "lat": 13.1112, "lng": 80.2612, "radius_meters": 600.0,
        "geocode_query": "Vyasarpadi, Chennai, Tamil Nadu, India"
    },
    {
        "id": "CHN038", "place": "Washermanpet", "category": "Neighbour of North Chennai", "anchor_area": "Washermanpet",
        "demo_safety_label": "moderately_safe", "day_risk_score": 45, "night_risk_score": 63, "route_risk_score": 54,
        "footfall": "Medium", "night_activity": "Medium", "lighting": "Medium", "isolation": "High",
        "recommendation": "Stay on active corridors", "demo_safety_score": 46,
        "lat": 13.1097, "lng": 80.2815, "radius_meters": 600.0,
        "geocode_query": "Washermanpet, Chennai, Tamil Nadu, India"
    },
    {
        "id": "CHN039", "place": "Tondiarpet", "category": "Northern & Peripheral", "anchor_area": "Tondiarpet",
        "demo_safety_label": "moderately_safe", "day_risk_score": 44, "night_risk_score": 67, "route_risk_score": 55,
        "footfall": "Medium", "night_activity": "Medium", "lighting": "Medium", "isolation": "High",
        "recommendation": "Avoid poorly lit interior lanes", "demo_safety_score": 45,
        "lat": 13.1239, "lng": 80.2879, "radius_meters": 600.0,
        "geocode_query": "Tondiarpet, Chennai, Tamil Nadu, India"
    },
    {
        "id": "CHN040", "place": "Kodungaiyur", "category": "Northern & Peripheral", "anchor_area": "Kodungaiyur",
        "demo_safety_label": "caution_at_night", "day_risk_score": 52, "night_risk_score": 74, "route_risk_score": 63,
        "footfall": "Low", "night_activity": "High", "lighting": "Low", "isolation": "High",
        "recommendation": "Avoid dim canal-side paths", "demo_safety_score": 37,
        "lat": 13.1367, "lng": 80.2678, "radius_meters": 600.0,
        "geocode_query": "Kodungaiyur, Chennai, Tamil Nadu, India"
    },
    {
        "id": "CHN041", "place": "Broadway", "category": "Commercial / Transit", "anchor_area": "Broadway",
        "demo_safety_label": "safe_day_caution_night", "day_risk_score": 38, "night_risk_score": 72, "route_risk_score": 55,
        "footfall": "Medium", "night_activity": "High", "lighting": "Medium", "isolation": "High",
        "recommendation": "Prefer main commercial routes after closing", "demo_safety_score": 45,
        "lat": 13.0901, "lng": 80.2845, "radius_meters": 550.0,
        "geocode_query": "Broadway, Chennai, Tamil Nadu, India"
    },
    {
        "id": "CHN042", "place": "George Town", "category": "Commercial / Transit", "anchor_area": "George Town",
        "demo_safety_label": "safe_day_caution_night", "day_risk_score": 35, "night_risk_score": 70, "route_risk_score": 53,
        "footfall": "Medium", "night_activity": "High", "lighting": "Medium", "isolation": "High",
        "recommendation": "Avoid deserted bazaar lanes late night", "demo_safety_score": 47,
        "lat": 13.0924, "lng": 80.2867, "radius_meters": 600.0,
        "geocode_query": "George Town, Chennai, Tamil Nadu, India"
    },
    {
        "id": "CHN043", "place": "Broken Bridge", "category": "Specific Safety Zone", "anchor_area": "Adyar",
        "demo_safety_label": "unsafe", "day_risk_score": 72, "night_risk_score": 90, "route_risk_score": 81,
        "footfall": "Low", "night_activity": "Very High", "lighting": "Very Low", "isolation": "Very High",
        "recommendation": "Avoid; choose connected main-road route", "demo_safety_score": 19,
        "lat": 12.9989, "lng": 80.2789, "radius_meters": 500.0,
        "geocode_query": "Broken Bridge, Chennai, Tamil Nadu, India"
    },
    {
        "id": "CHN044", "place": "Marina Beach Dark Stretches", "category": "Specific Safety Zone", "anchor_area": "Marina Beach",
        "demo_safety_label": "caution_at_night", "day_risk_score": 45, "night_risk_score": 82, "route_risk_score": 64,
        "footfall": "Low", "night_activity": "High", "lighting": "Medium", "isolation": "High",
        "recommendation": "Stay in active/public sections", "demo_safety_score": 36,
        "lat": 13.0489, "lng": 80.2834, "radius_meters": 650.0,
        "geocode_query": "Marina Beach Dark Stretches, Chennai, Tamil Nadu, India"
    },
    {
        "id": "CHN045", "place": "Marina Beach Main Promenade", "category": "Neighbour of Marina Beach", "anchor_area": "Marina Beach",
        "demo_safety_label": "moderately_safe", "day_risk_score": 32, "night_risk_score": 58, "route_risk_score": 45,
        "footfall": "High", "night_activity": "Medium", "lighting": "High", "isolation": "Medium",
        "recommendation": "Prefer populated promenade", "demo_safety_score": 55,
        "lat": 13.0556, "lng": 80.2821, "radius_meters": 650.0,
        "geocode_query": "Marina Beach Main Promenade, Chennai, Tamil Nadu, India"
    },
    {
        "id": "CHN046", "place": "Besant Nagar Beach Interior", "category": "Specific Safety Zone", "anchor_area": "Besant Nagar",
        "demo_safety_label": "caution_at_night", "day_risk_score": 48, "night_risk_score": 80, "route_risk_score": 64,
        "footfall": "Low", "night_activity": "High", "lighting": "Medium", "isolation": "High",
        "recommendation": "Avoid isolated sand-side areas", "demo_safety_score": 36,
        "lat": 12.9967, "lng": 80.2712, "radius_meters": 500.0,
        "geocode_query": "Besant Nagar Beach Interior, Chennai, Tamil Nadu, India"
    },
    {
        "id": "CHN047", "place": "ECR Isolated Pockets", "category": "Specific Safety Zone", "anchor_area": "ECR",
        "demo_safety_label": "caution_at_night", "day_risk_score": 55, "night_risk_score": 86, "route_risk_score": 71,
        "footfall": "Low", "night_activity": "Very High", "lighting": "Low", "isolation": "Very High",
        "recommendation": "Avoid isolated coastal roads", "demo_safety_score": 29,
        "lat": 12.8756, "lng": 80.2456, "radius_meters": 700.0,
        "geocode_query": "ECR Isolated Pockets, Chennai, Tamil Nadu, India"
    },
    {
        "id": "CHN048", "place": "Outer Ring Road Unlit Sections", "category": "Specific Safety Zone", "anchor_area": "ORR",
        "demo_safety_label": "caution_at_night", "day_risk_score": 50, "night_risk_score": 78, "route_risk_score": 64,
        "footfall": "Low", "night_activity": "High", "lighting": "Low", "isolation": "High",
        "recommendation": "Prefer well-lit connected routes", "demo_safety_score": 36,
        "lat": 12.9789, "lng": 80.0567, "radius_meters": 800.0,
        "geocode_query": "Outer Ring Road Unlit Sections, Chennai, Tamil Nadu, India"
    },
    {
        "id": "CHN049", "place": "Kalakattukuppam", "category": "Specific Safety Zone", "anchor_area": "ECR",
        "demo_safety_label": "caution_at_night", "day_risk_score": 54, "night_risk_score": 80, "route_risk_score": 67,
        "footfall": "Low", "night_activity": "High", "lighting": "Low", "isolation": "High",
        "recommendation": "Avoid isolated beach access points", "demo_safety_score": 33,
        "lat": 12.8123, "lng": 80.2423, "radius_meters": 550.0,
        "geocode_query": "Kalakattukuppam, Chennai, Tamil Nadu, India"
    },
    {
        "id": "CHN050", "place": "Ayothi Kuppam", "category": "Northern / Central Pocket", "anchor_area": "Marina",
        "demo_safety_label": "caution_advised", "day_risk_score": 52, "night_risk_score": 73, "route_risk_score": 63,
        "footfall": "Medium", "night_activity": "High", "lighting": "Low", "isolation": "High",
        "recommendation": "Prefer active main roads", "demo_safety_score": 37,
        "lat": 13.0534, "lng": 80.2812, "radius_meters": 500.0,
        "geocode_query": "Ayothi Kuppam, Chennai, Tamil Nadu, India"
    },
    {
        "id": "CHN051", "place": "Vadapalani Metro Exits", "category": "Transit Pocket", "anchor_area": "Vadapalani",
        "demo_safety_label": "moderately_safe", "day_risk_score": 40, "night_risk_score": 62, "route_risk_score": 51,
        "footfall": "High", "night_activity": "Medium", "lighting": "Medium", "isolation": "Medium",
        "recommendation": "Stay near active station exits", "demo_safety_score": 49,
        "lat": 13.0512, "lng": 80.2112, "radius_meters": 500.0,
        "geocode_query": "Vadapalani Metro Exits, Chennai, Tamil Nadu, India"
    },
    {
        "id": "CHN052", "place": "Pallikaranai 200-ft Road Dark Stretches", "category": "Specific Safety Zone", "anchor_area": "Pallikaranai",
        "demo_safety_label": "caution_at_night", "day_risk_score": 48, "night_risk_score": 70, "route_risk_score": 59,
        "footfall": "Medium", "night_activity": "High", "lighting": "Medium", "isolation": "High",
        "recommendation": "Prefer lit intersections", "demo_safety_score": 41,
        "lat": 12.9412, "lng": 80.2089, "radius_meters": 600.0,
        "geocode_query": "Pallikaranai 200-ft Road Dark Stretches, Chennai, Tamil Nadu, India"
    },
    {
        "id": "CHN053", "place": "Maduravoyal–Poonamallee Highway Service Lanes", "category": "Specific Safety Zone", "anchor_area": "Maduravoyal",
        "demo_safety_label": "caution_at_night", "day_risk_score": 46, "night_risk_score": 72, "route_risk_score": 59,
        "footfall": "Low", "night_activity": "High", "lighting": "Low", "isolation": "High",
        "recommendation": "Avoid isolated service lanes", "demo_safety_score": 41,
        "lat": 13.0589, "lng": 80.1456, "radius_meters": 650.0,
        "geocode_query": "Maduravoyal–Poonamallee Highway Service Lanes, Chennai, Tamil Nadu, India"
    },
    {
        "id": "CHN054", "place": "Ambattur Industrial Estate Edges", "category": "Specific Safety Zone", "anchor_area": "Ambattur",
        "demo_safety_label": "caution_at_night", "day_risk_score": 50, "night_risk_score": 75, "route_risk_score": 63,
        "footfall": "Low", "night_activity": "High", "lighting": "Low", "isolation": "High",
        "recommendation": "Prefer main corridors after business hours", "demo_safety_score": 37,
        "lat": 13.0898, "lng": 80.1612, "radius_meters": 650.0,
        "geocode_query": "Ambattur Industrial Estate Edges, Chennai, Tamil Nadu, India"
    },
    {
        "id": "CHN055", "place": "Choolai", "category": "Northern / Central Pocket", "anchor_area": "Choolai",
        "demo_safety_label": "moderately_safe", "day_risk_score": 46, "night_risk_score": 68, "route_risk_score": 57,
        "footfall": "Medium", "night_activity": "High", "lighting": "Medium", "isolation": "High",
        "recommendation": "Avoid poorly lit interior junctions", "demo_safety_score": 43,
        "lat": 13.0898, "lng": 80.2678, "radius_meters": 550.0,
        "geocode_query": "Choolai, Chennai, Tamil Nadu, India"
    },
    {
        "id": "CHN056", "place": "Choolaimedu", "category": "Neighbour of Nungambakkam", "anchor_area": "Choolaimedu",
        "demo_safety_label": "moderately_safe", "day_risk_score": 42, "night_risk_score": 61, "route_risk_score": 52,
        "footfall": "Medium", "night_activity": "Medium", "lighting": "Medium", "isolation": "Medium",
        "recommendation": "Prefer active roads", "demo_safety_score": 48,
        "lat": 13.0612, "lng": 80.2245, "radius_meters": 550.0,
        "geocode_query": "Choolaimedu, Chennai, Tamil Nadu, India"
    },
]


async def seed_chennai_datasets(db: AsyncSession) -> None:
    """
    Idempotent seeder: Seeds Chennai Police Stations and Chennai Safety Zones
    into PostgreSQL if tables are empty or records are missing.
    """
    try:
        # Check police stations
        ps_count = await db.scalar(select(func.count(PoliceStation.id)))
        if not ps_count or ps_count == 0:
            logger.info("seeding_chennai_police_stations", total=len(CHENNAI_POLICE_STATIONS_DATA))
            stations = [
                PoliceStation(
                    city="Chennai",
                    zone=item["zone"],
                    sub_division=item["sub_division"].strip(),
                    station_name=item["station_name"].strip(),
                    contact_number=item["contact_number"].strip(),
                    address=item.get("address"),
                    latitude=item["lat"],
                    longitude=item["lng"],
                    source_info="Chennai Police Department directory - informational prototype data",
                    is_verified=False,
                )
                for item in CHENNAI_POLICE_STATIONS_DATA
            ]
            db.add_all(stations)
            await db.commit()
            logger.info("seeded_chennai_police_stations_success", count=len(stations))

        # Check safety zones
        sz_count = await db.scalar(select(func.count(SafetyZone.id)))
        if not sz_count or sz_count == 0:
            logger.info("seeding_chennai_safety_zones", total=len(CHENNAI_SAFETY_ZONES_DATA))
            zones = [
                SafetyZone(
                    id=item["id"],
                    place=item["place"],
                    category=item["category"],
                    anchor_area=item["anchor_area"],
                    demo_safety_label=item["demo_safety_label"],
                    day_risk_score=item["day_risk_score"],
                    night_risk_score=item["night_risk_score"],
                    route_risk_score=item["route_risk_score"],
                    footfall=item["footfall"],
                    night_activity=item["night_activity"],
                    lighting=item["lighting"],
                    isolation=item["isolation"],
                    recommendation=item["recommendation"],
                    data_status="DEMO / UNVERIFIED — do not present as official crime statistics",
                    source_basis="User-provided Chennai safety notes; neighbouring areas expanded for prototype mapping",
                    crime_data="No verified incident counts",
                    use_for_routing=True,
                    geocode_query=item["geocode_query"],
                    demo_safety_score=item["demo_safety_score"],
                    latitude=item["lat"],
                    longitude=item["lng"],
                    radius_meters=item.get("radius_meters", 600.0),
                )
                for item in CHENNAI_SAFETY_ZONES_DATA
            ]
            db.add_all(zones)
            await db.commit()
            logger.info("seeded_chennai_safety_zones_success", count=len(zones))
    except Exception as e:
        logger.error("failed_to_seed_chennai_data", error=str(e))
        await db.rollback()
