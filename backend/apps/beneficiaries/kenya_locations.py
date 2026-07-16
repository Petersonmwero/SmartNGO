"""
Kenya administrative-boundary reference data for the cascading location
picker (county → constituency → ward → location → sub-location), mirroring
the eCitizen hierarchy.

Coverage:
- KENYA_COUNTIES: all 47 counties.
- COUNTY_CONSTITUENCIES: the complete, real constituency list for every
  county (290 constituencies, per IEBC delimitation).
- CONSTITUENCY_WARDS: ward lists for **all 290 constituencies** (curated
  for the demo/urban counties; the remainder supplied by the project — see
  HANDOVER for provenance).
- WARD_LOCATIONS / LOCATION_SUBLOCATION: curated locations/sub-locations
  for a representative ward subset. Wards without curated data get
  generated "<ward> A/B" locations (see the loop at the bottom) so the
  Location level is always selectable; sub-locations for generated
  locations stay empty and the picker shows them as skippable.
"""

KENYA_COUNTIES = [
    "Mombasa", "Kwale", "Kilifi", "Tana River", "Lamu", "Taita-Taveta",
    "Garissa", "Wajir", "Mandera", "Marsabit", "Isiolo", "Meru",
    "Tharaka-Nithi", "Embu", "Kitui", "Machakos", "Makueni", "Nyandarua",
    "Nyeri", "Kirinyaga", "Murang'a", "Kiambu", "Turkana", "West Pokot",
    "Samburu", "Trans Nzoia", "Uasin Gishu", "Elgeyo-Marakwet", "Nandi",
    "Baringo", "Laikipia", "Nakuru", "Narok", "Kajiado", "Kericho", "Bomet",
    "Kakamega", "Vihiga", "Bungoma", "Busia", "Siaya", "Kisumu", "Homa Bay",
    "Migori", "Kisii", "Nyamira", "Nairobi",
]

COUNTY_CONSTITUENCIES = {
    "Mombasa": ["Changamwe", "Jomvu", "Kisauni", "Nyali", "Likoni", "Mvita"],
    "Kwale": ["Msambweni", "Lunga Lunga", "Matuga", "Kinango"],
    "Kilifi": [
        "Kilifi North", "Kilifi South", "Kaloleni", "Rabai", "Ganze",
        "Malindi", "Magarini",
    ],
    "Tana River": ["Garsen", "Galole", "Bura"],
    "Lamu": ["Lamu East", "Lamu West"],
    "Taita-Taveta": ["Taveta", "Wundanyi", "Mwatate", "Voi"],
    "Garissa": [
        "Garissa Township", "Balambala", "Lagdera", "Dadaab", "Fafi", "Ijara",
    ],
    "Wajir": [
        "Wajir North", "Wajir East", "Tarbaj", "Wajir West", "Eldas",
        "Wajir South",
    ],
    "Mandera": [
        "Mandera West", "Banissa", "Mandera North", "Mandera South",
        "Mandera East", "Lafey",
    ],
    "Marsabit": ["Moyale", "North Horr", "Saku", "Laisamis"],
    "Isiolo": ["Isiolo North", "Isiolo South"],
    "Meru": [
        "Igembe South", "Igembe Central", "Igembe North", "Tigania West",
        "Tigania East", "North Imenti", "Buuri", "Central Imenti",
        "South Imenti",
    ],
    "Tharaka-Nithi": ["Maara", "Chuka/Igambang'ombe", "Tharaka"],
    "Embu": ["Manyatta", "Runyenjes", "Mbeere South", "Mbeere North"],
    "Kitui": [
        "Mwingi North", "Mwingi West", "Mwingi Central", "Kitui West",
        "Kitui Rural", "Kitui Central", "Kitui East", "Kitui South",
    ],
    "Machakos": [
        "Masinga", "Yatta", "Kangundo", "Matungulu", "Kathiani", "Mavoko",
        "Machakos Town", "Mwala",
    ],
    "Makueni": [
        "Mbooni", "Kilome", "Kaiti", "Makueni", "Kibwezi West", "Kibwezi East",
    ],
    "Nyandarua": ["Kinangop", "Kipipiri", "Ol Kalou", "Ol Jorok", "Ndaragwa"],
    "Nyeri": ["Tetu", "Kieni", "Mathira", "Othaya", "Mukurweini", "Nyeri Town"],
    "Kirinyaga": ["Mwea", "Gichugu", "Ndia", "Kirinyaga Central"],
    "Murang'a": [
        "Kangema", "Mathioya", "Kiharu", "Kigumo", "Maragwa", "Kandara",
        "Gatanga",
    ],
    "Kiambu": [
        "Gatundu South", "Gatundu North", "Juja", "Thika Town", "Ruiru",
        "Githunguri", "Kiambu", "Kiambaa", "Kabete", "Kikuyu", "Limuru",
        "Lari",
    ],
    "Turkana": [
        "Turkana North", "Turkana West", "Turkana Central", "Loima",
        "Turkana South", "Turkana East",
    ],
    "West Pokot": ["Kapenguria", "Sigor", "Kacheliba", "Pokot South"],
    "Samburu": ["Samburu West", "Samburu North", "Samburu East"],
    "Trans Nzoia": ["Kwanza", "Endebess", "Saboti", "Kiminini", "Cherangany"],
    "Uasin Gishu": ["Soy", "Turbo", "Moiben", "Ainabkoi", "Kapseret", "Kesses"],
    "Elgeyo-Marakwet": [
        "Marakwet East", "Marakwet West", "Keiyo North", "Keiyo South",
    ],
    "Nandi": [
        "Tinderet", "Aldai", "Nandi Hills", "Chesumei", "Emgwen", "Mosop",
    ],
    "Baringo": [
        "Tiaty", "Baringo North", "Baringo Central", "Baringo South",
        "Mogotio", "Eldama Ravine",
    ],
    "Laikipia": ["Laikipia West", "Laikipia East", "Laikipia North"],
    "Nakuru": [
        "Molo", "Njoro", "Naivasha", "Gilgil", "Kuresoi South",
        "Kuresoi North", "Subukia", "Rongai", "Bahati", "Nakuru Town West",
        "Nakuru Town East",
    ],
    "Narok": [
        "Kilgoris", "Emurua Dikirr", "Narok North", "Narok East",
        "Narok South", "Narok West",
    ],
    "Kajiado": [
        "Kajiado North", "Kajiado Central", "Kajiado East", "Kajiado West",
        "Kajiado South",
    ],
    "Kericho": [
        "Kipkelion East", "Kipkelion West", "Ainamoi", "Bureti", "Belgut",
        "Sigowet/Soin",
    ],
    "Bomet": ["Sotik", "Chepalungu", "Bomet East", "Bomet Central", "Konoin"],
    "Kakamega": [
        "Lugari", "Likuyani", "Malava", "Lurambi", "Navakholo",
        "Mumias West", "Mumias East", "Matungu", "Butere", "Khwisero",
        "Shinyalu", "Ikolomani",
    ],
    "Vihiga": ["Vihiga", "Sabatia", "Hamisi", "Luanda", "Emuhaya"],
    "Bungoma": [
        "Mt. Elgon", "Sirisia", "Kabuchai", "Bumula", "Kanduyi",
        "Webuye East", "Webuye West", "Kimilili", "Tongaren",
    ],
    "Busia": [
        "Teso North", "Teso South", "Nambale", "Matayos", "Butula",
        "Funyula", "Budalangi",
    ],
    "Siaya": ["Ugenya", "Ugunja", "Alego Usonga", "Gem", "Bondo", "Rarieda"],
    "Kisumu": [
        "Kisumu East", "Kisumu West", "Kisumu Central", "Seme", "Nyando",
        "Muhoroni", "Nyakach",
    ],
    "Homa Bay": [
        "Kasipul", "Kabondo Kasipul", "Karachuonyo", "Rangwe",
        "Homa Bay Town", "Ndhiwa", "Suba North", "Suba South",
    ],
    "Migori": [
        "Rongo", "Awendo", "Suna East", "Suna West", "Uriri", "Nyatike",
        "Kuria West", "Kuria East",
    ],
    "Kisii": [
        "Bonchari", "South Mugirango", "Bomachoge Borabu", "Bobasi",
        "Bomachoge Chache", "Nyaribari Masaba", "Nyaribari Chache",
        "Kitutu Chache North", "Kitutu Chache South",
    ],
    "Nyamira": ["Kitutu Masaba", "West Mugirango", "North Mugirango", "Borabu"],
    "Nairobi": [
        "Westlands", "Dagoretti North", "Dagoretti South", "Langata",
        "Kibra", "Roysambu", "Kasarani", "Ruaraka", "Embakasi South",
        "Embakasi North", "Embakasi Central", "Embakasi East",
        "Embakasi West", "Makadara", "Kamukunji", "Starehe", "Mathare",
    ],
}

CONSTITUENCY_WARDS = {
    # ── Nairobi ──────────────────────────────────────────────────────────
    "Westlands": [
        "Kitisuru", "Parklands/Highridge", "Karura", "Kangemi",
        "Mountain View",
    ],
    "Dagoretti North": [
        "Kilimani", "Kawangware", "Gatina", "Kileleshwa", "Kabiro",
    ],
    "Dagoretti South": [
        "Mutu-ini", "Ngando", "Riruta", "Uthiru/Ruthimitu", "Waithaka",
    ],
    "Langata": [
        "Karen", "Nairobi West", "Mugumo-ini", "South C", "Nyayo Highrise",
    ],
    "Kibra": [
        "Laini Saba", "Lindi", "Makina", "Woodley/Kenyatta Golf Course",
        "Sarang'ombe",
    ],
    "Roysambu": ["Githurai", "Kahawa West", "Zimmerman", "Roysambu", "Kahawa"],
    "Kasarani": ["Clay City", "Mwiki", "Kasarani", "Njiru", "Ruai"],
    "Ruaraka": [
        "Baba Dogo", "Utalii", "Mathare North", "Lucky Summer", "Korogocho",
    ],
    "Embakasi South": [
        "Imara Daima", "Kwa Njenga", "Kwa Reuben", "Pipeline", "Kware",
    ],
    "Embakasi North": [
        "Kariobangi North", "Dandora Area I", "Dandora Area II",
        "Dandora Area III", "Dandora Area IV",
    ],
    "Embakasi Central": [
        "Kayole North", "Kayole Central", "Kayole South", "Komarock",
        "Matopeni/Spring Valley",
    ],
    "Embakasi East": [
        "Upper Savanna", "Lower Savanna", "Embakasi", "Utawala", "Mihango",
    ],
    "Embakasi West": ["Umoja I", "Umoja II", "Mowlem", "Kariobangi South"],
    "Makadara": ["Maringo/Hamza", "Viwandani", "Harambee", "Makongeni"],
    "Kamukunji": [
        "Pumwani", "Eastleigh North", "Eastleigh South", "Airbase",
        "California",
    ],
    "Starehe": [
        "Nairobi Central", "Ngara", "Pangani", "Ziwani/Kariokor",
        "Landimawe", "Nairobi South",
    ],
    "Mathare": [
        "Hospital", "Mabatini", "Huruma", "Ngei", "Mlango Kubwa", "Kiamaiko",
    ],
    # ── Mombasa ──────────────────────────────────────────────────────────
    "Changamwe": ["Port Reitz", "Kipevu", "Airport", "Changamwe", "Chaani"],
    "Jomvu": ["Jomvu Kuu", "Miritini", "Mikindani"],
    "Kisauni": [
        "Mjambere", "Junda", "Bamburi", "Mwakirunge", "Mtopanga",
        "Magogoni", "Shanzu",
    ],
    "Nyali": [
        "Frere Town", "Ziwa La Ng'ombe", "Mkomani", "Kongowea", "Kadzandani",
    ],
    "Likoni": ["Mtongwe", "Shika Adabu", "Bofu", "Likoni", "Timbwani"],
    "Mvita": [
        "Mji Wa Kale/Makadara", "Tudor", "Tononoka", "Shimanzi/Ganjoni",
        "Majengo",
    ],
    # ── Kisumu ───────────────────────────────────────────────────────────
    "Kisumu East": [
        "Kajulu", "Kolwa East", "Manyatta B", "Nyalenda A", "Kolwa Central",
    ],
    "Kisumu West": [
        "South West Kisumu", "Central Kisumu", "Kisumu North", "West Kisumu",
        "North West Kisumu",
    ],
    "Kisumu Central": [
        "Railways", "Migosi", "Shaurimoyo Kaloleni", "Market Milimani",
        "Kondele", "Nyalenda B",
    ],
    "Seme": ["West Seme", "Central Seme", "East Seme", "North Seme"],
    "Nyando": [
        "East Kano/Wawidhi", "Awasi/Onjiko", "Ahero", "Kabonyo/Kanyagwal",
        "Kobura",
    ],
    "Muhoroni": [
        "Miwani", "Ombeyi", "Masogo/Nyang'oma", "Chemelil", "Muhoroni/Koru",
    ],
    "Nyakach": [
        "South West Nyakach", "North Nyakach", "Central Nyakach",
        "West Nyakach", "South East Nyakach",
    ],
    # ── Nakuru ───────────────────────────────────────────────────────────
    "Molo": ["Mariashoni", "Elburgon", "Turi", "Molo"],
    "Njoro": ["Mau Narok", "Mauche", "Kihingo", "Nessuit", "Lare", "Njoro"],
    "Naivasha": [
        "Biashara", "Hells Gate", "Lake View", "Maiella", "Mai Mahiu",
        "Olkaria", "Naivasha East", "Viwandani",
    ],
    "Gilgil": [
        "Gilgil", "Elementaita", "Mbaruk/Eburu", "Malewa West", "Murindati",
    ],
    "Kuresoi South": ["Amalo", "Keringet", "Kiptagich", "Tinet"],
    "Kuresoi North": ["Kiptororo", "Nyota", "Sirikwa", "Kamara"],
    "Subukia": ["Subukia", "Waseges", "Kabazi"],
    "Rongai": ["Menengai West", "Soin", "Visoi", "Mosop", "Solai"],
    "Bahati": ["Dundori", "Kabatini", "Kiamaina", "Lanet/Umoja", "Bahati"],
    "Nakuru Town West": [
        "Barut", "London", "Kaptembwo", "Kapkures", "Rhoda", "Shaabab",
    ],
    "Nakuru Town East": [
        "Biashara", "Kivumbini", "Flamingo", "Menengai", "Nakuru East",
    ],
    # ── Kiambu ───────────────────────────────────────────────────────────
    "Gatundu South": ["Kiamwangi", "Kiganjo", "Ndarugu", "Ngenda"],
    "Gatundu North": ["Gituamba", "Githobokoni", "Chania", "Mang'u"],
    "Juja": ["Murera", "Theta", "Juja", "Witeithie", "Kalimoni"],
    "Thika Town": ["Township", "Kamenu", "Hospital", "Gatuanyaga", "Ngoliba"],
    "Ruiru": [
        "Gitothua", "Biashara", "Gatongora", "Kahawa Sukari",
        "Kahawa Wendani", "Kiuu", "Mwiki", "Mwihoko",
    ],
    "Githunguri": ["Githunguri", "Githiga", "Ikinu", "Ngewa", "Komothai"],
    "Kiambu": ["Ting'ang'a", "Ndumberi", "Riabai", "Township"],
    "Kiambaa": ["Cianda", "Karuri", "Ndenderu", "Muchatha", "Kihara"],
    "Kabete": ["Gitaru", "Muguga", "Nyadhuna", "Kabete", "Uthiru"],
    "Kikuyu": ["Karai", "Nachu", "Sigona", "Kikuyu", "Kinoo"],
    "Limuru": [
        "Bibirioni", "Limuru Central", "Ndeiya", "Limuru East",
        "Ngecha Tigoni",
    ],
    "Lari": ["Kinale", "Kijabe", "Nyanduma", "Kamburu", "Lari/Kirenga"],
    # ── Baringo ──────────────────────────────────────────────────────────
    "Tiaty": [
        "Tirioko", "Kolowa", "Ribkwo", "Silale", "Loiyamorock",
        "Tangulbei/Korossi", "Churo/Amaya",
    ],
    "Baringo North": [
        "Barwessa", "Kabartonjo", "Saimo/Kipsaraman", "Saimo/Soi", "Bartabwa",
    ],
    "Baringo Central": [
        "Kabarnet", "Sacho", "Tenges", "Ewalel Chapchap", "Kapropita",
    ],
    "Baringo South": ["Marigat", "Ilchamus", "Mochongoi", "Mukutani"],
    "Mogotio": ["Mogotio", "Emining", "Kisanana"],
    "Eldama Ravine": [
        "Lembus", "Lembus Kwen", "Ravine", "Mumberes/Maji Mazuri",
        "Lembus/Perkerra",
    ],
    # ── Turkana ──────────────────────────────────────────────────────────
    "Turkana North": [
        "Kaeris", "Lake Zone", "Lapur", "Kaaleng/Kaikor", "Kibish",
        "Nakalale",
    ],
    "Turkana West": [
        "Kakuma", "Lopur", "Letea", "Songot", "Kalobeyei", "Lokichoggio",
        "Nanaam",
    ],
    "Turkana Central": [
        "Kerio Delta", "Kang'atotha", "Kalokol", "Lodwar Township",
        "Kanamkemer",
    ],
    "Loima": ["Kotaruk/Lobei", "Turkwel", "Loima", "Lokiriama/Lorengippi"],
    "Turkana South": [
        "Kaputir", "Katilu", "Lobokat", "Kalapata", "Lokichar",
    ],
    "Turkana East": ["Kapedo/Napeitom", "Katilia", "Lokori/Kochodin"],
    # ── Kwale ────────────────────────────────────────────────────────────
    "Msambweni": ["Gombato Bongwe", "Ukunda", "Kinondo", "Ramisi"],
    "Lunga Lunga": [
        "Pongwe/Kikoneni", "Dzinayi", "Shimba Hills", "Majoreni",
    ],
    "Matuga": ["Tsimba Golini", "Waa", "Tiwi", "Kubo South", "Mkongani"],
    "Kinango": [
        "Ndavaya", "Puma", "Kinango", "Mackinnon Road",
        "Chengoni/Samburu", "Mwavumbo", "Kasemeni",
    ],
    # ── Kilifi ───────────────────────────────────────────────────────────
    "Kilifi North": [
        "Tezo", "Sokoni", "Kibarani", "Dabaso", "Matsangoni", "Watamu",
        "Mnarani",
    ],
    "Kilifi South": [
        "Junju", "Mwarakaya", "Shimo La Tewa", "Chasimba", "Mtepeni",
    ],
    "Kaloleni": ["Mariakani", "Kayafungo", "Kaloleni", "Mwanambi"],
    "Rabai": ["Ruruma", "Kambe/Ribe", "Rabai/Kisurutini"],
    "Ganze": ["Ganze", "Bamba", "Jaribuni", "Sokoke"],
    "Malindi": ["Jilore", "Kakuyuni", "Ganda", "Malindi Town", "Shella"],
    "Magarini": ["Marafa", "Magarini", "Gongoni", "Adu", "Garashi", "Sabaki"],
    # ── Tana River ───────────────────────────────────────────────────────
    "Garsen": [
        "Garsen South", "Garsen Central", "Garsen West", "Garsen North",
        "Garsen East",
    ],
    "Galole": ["Kinakomba", "Mikinduni", "Chewani", "Wayu"],
    "Bura": ["Bangale", "Sala", "Madogo", "Tana North", "Bura"],
    # ── Lamu ─────────────────────────────────────────────────────────────
    "Lamu East": ["Faza", "Kiunga", "Basuba"],
    "Lamu West": ["Shela", "Mkomani", "Hindi", "Hongwe", "Witu", "Bahari"],
    # ── Taita-Taveta ─────────────────────────────────────────────────────
    "Taveta": ["Chala", "Mahoo", "Bomani", "Mboghoni", "Mata"],
    "Wundanyi": [
        "Wundanyi/Mbale", "Werugha", "Wumingu/Kishushe", "Mwanda/Mgange",
    ],
    "Mwatate": ["Rong'e", "Mwatate", "Bura", "Chawia", "Wusi/Kishamba"],
    "Voi": ["Mbololo", "Sagala", "Kaloleni", "Marungu", "Kasigau", "Ngolia"],
    # ── Garissa ──────────────────────────────────────────────────────────
    "Garissa Township": ["Galbet", "Township", "Waberi", "Gorgora", "Midhi"],
    "Balambala": ["Balambala", "Danyere", "Jarajila", "Damajale", "Jara Jara"],
    "Lagdera": ["Modogashe", "Benane", "Goreale", "Maalimin", "Sabena"],
    "Dadaab": ["Dadaab", "Lafoye", "Liboi", "Dertu", "Abakaile"],
    "Fafi": ["Bura", "Dekaharia", "Jarajila", "Fafi", "Nanighi"],
    "Ijara": ["Ijara", "Masalani", "Hulugho", "Sangailu", "Ishaqbini"],
    # ── Wajir ────────────────────────────────────────────────────────────
    "Wajir North": ["Gurar", "Bute", "Korondile", "Malkagufu"],
    "Wajir East": ["Wagberi", "Township", "Barwago", "Khorof Harar"],
    "Tarbaj": ["Tarbaj", "Wargadud", "Sarman", "Hadado"],
    "Wajir West": ["Ganyure/Wagalla", "Uglam", "Eldas", "Diif"],
    "Eldas": ["Eldas", "Della", "Lakoley South/Basir", "Lakoley North"],
    "Wajir South": [
        "Ademasajida", "Afgoi", "Dadaja Bulla", "Habaswein",
        "Lagboghol South",
    ],
    # ── Mandera ──────────────────────────────────────────────────────────
    "Mandera North": ["Takaba South", "Takaba", "Dandu", "Dertu", "Maikona"],
    "Banissa": ["Banissa", "Derkhale", "Guba", "Moi"],
    "Mandera East": ["Khalalio", "Neboi", "Township", "Libehia", "Warankara"],
    "Lafey": ["Lafey", "Fino", "Shimbir Fatuma", "Arabia"],
    "Mandera West": [
        "Elwak North", "Elwak South", "Wargadud", "Butiye", "Arabia",
    ],
    "Mandera South": [
        "Kutulo", "Ashabito", "Morothile", "Malkamari", "Damasa",
    ],
    # ── Marsabit ─────────────────────────────────────────────────────────
    "Moyale": [
        "Butiye", "Sololo", "Heillu/Manyatta", "Moyale Township", "Golbo",
    ],
    "North Horr": ["Turbi", "North Horr", "Maikona", "Dukana", "Illaut"],
    "Saku": ["Karare", "Marsabit Central", "Marsabit North", "Saku"],
    "Laisamis": ["Laisamis", "Loiyangalani", "Logologo", "Korr/Ngurunit"],
    # ── Isiolo ───────────────────────────────────────────────────────────
    "Isiolo North": [
        "Wabera", "Bulla Pesa", "Ngare Mara", "Isiolo Township", "Bulapesa",
    ],
    "Isiolo South": ["Garbatulla", "Kinna", "Cherab", "Chari", "Oldonyiro"],
    # ── Meru ─────────────────────────────────────────────────────────────
    "Igembe South": [
        "Akachiu", "Kanuni", "Kiegoi/Antubochiu", "Maua", "Lare",
    ],
    "Igembe Central": ["Igembe East", "Njia", "Township", "Kangeta"],
    "Igembe North": [
        "Antuambui", "Ntunene", "Antubochiu", "Naathu", "Amwathi",
    ],
    "Tigania West": ["Mbeu", "Kiguchwa", "Mithara", "Thangatha", "Mikinduri"],
    "Tigania East": ["Njorua", "Karama", "Nkomo", "Akithi", "Giaki"],
    "North Imenti": [
        "Municipality", "Ntima East", "Ntima West", "Nyaki West",
        "Nyaki East",
    ],
    "Buuri": ["Timau", "Kisima", "Ruiri/Rwarera", "Meru North", "Kibirichia"],
    "Central Imenti": ["Kiagu", "Mitunguu", "Igoji East", "Igoji West"],
    "South Imenti": [
        "Abothuguchi West", "Abothuguchi Central", "Kiagu", "Mitunguu",
    ],
    # ── Tharaka-Nithi ────────────────────────────────────────────────────
    "Maara": ["Mwimbi", "Muthambi", "Chogoria", "Mariani", "Nkuene"],
    "Chuka/Igambang'ombe": [
        "Karingani", "Magumoni", "Mugwe", "Igambang'ombe",
    ],
    "Tharaka": ["Tharaka North", "Tharaka South", "Gatunga", "Mukothima"],
    # ── Embu ─────────────────────────────────────────────────────────────
    "Manyatta": ["Kirimari", "Mbeti North", "Nthawa", "Muminji", "Evurore"],
    "Runyenjes": [
        "Gaturi South", "Kagaari South", "Central", "Kagaari North",
        "Gaturi North",
    ],
    "Mbeere South": ["Mbeti South", "Mavuria", "Kiambere", "Makima"],
    "Mbeere North": ["Nthawa", "Mwea", "Makima", "Evurore", "Kiambere"],
    # ── Kitui ────────────────────────────────────────────────────────────
    "Mwingi North": ["Kyuso", "Mumoni", "Tseikuru", "Tharaka"],
    "Mwingi West": [
        "Ngomeni", "Kyome/Thaana", "Nguutani", "Migwani", "Kiomo/Kyethani",
    ],
    "Mwingi Central": ["Kivou", "Nguni", "Nuu", "Mui", "Waita"],
    "Kitui West": [
        "Mutonguni", "Kauwi", "Matinyani", "Kwa Mutonga/Kithumula",
    ],
    "Kitui Rural": [
        "Kisasi", "Mwanyani", "Kakundi", "Kanziku", "Zombe/Mwitika",
    ],
    "Kitui Central": [
        "Miambani", "Township", "Kyangwithya West", "Mulango",
        "Kyangwithya East",
    ],
    "Kitui East": [
        "Zombe/Mwitika", "Chuluni", "Nzou", "Mutito/Kaliku",
        "Ikanga/Kyatune",
    ],
    "Kitui South": ["Mutomo", "Mutha", "Ikutha", "Athi", "Kanzawo"],
    # ── Machakos ─────────────────────────────────────────────────────────
    "Masinga": [
        "Kivaa", "Masinga Central", "Ekalakala", "Muthesya", "Ndithini",
    ],
    "Yatta": ["Ndalani", "Matuu", "Kithimani", "Ikombe", "Katangi"],
    "Kangundo": [
        "Kangundo North", "Kangundo Central", "Kangundo East",
        "Kangundo West",
    ],
    "Matungulu": [
        "Tala", "Matungulu North", "Matungulu East", "Matungulu West",
        "Kyeleni",
    ],
    "Kathiani": [
        "Mitaboni", "Kathiani Central", "Upper Kaewa/Iveti", "Lower Kaewa",
    ],
    "Mavoko": ["Athi River", "Kinanie", "Muthwani", "Syokimau/Mulolongo"],
    "Machakos Town": [
        "Mumbuni North", "Mua", "Mutituni", "Machakos Central", "Kalama",
        "Mbiuni", "Mumbuni West",
    ],
    "Mwala": ["Mwala", "Mbete-Mwau", "Nguluni", "Yathui"],
    # ── Makueni ──────────────────────────────────────────────────────────
    "Mbooni": ["Tulimani", "Mbooni", "Kithungo/Kitundu", "Kisau/Kiteta"],
    "Kilome": ["Kasikeu", "Mukaa", "Kiima Kimwe/Kalanzoni"],
    "Kaiti": ["Ilkerin", "Ala", "Kaiti", "Ukia", "Kee"],
    "Makueni": ["Wote", "Muvau/Kikuumini", "Mavindini", "Kitise/Kithuki"],
    "Kibwezi West": [
        "Masongaleni", "Mtito Andei", "Thange", "Ivingoni/Nzambani",
    ],
    "Kibwezi East": ["Makindu", "Nguu/Masumba", "Kibwezi", "Emali/Mulala"],
    # ── Nyandarua ────────────────────────────────────────────────────────
    "Kinangop": [
        "Engineer", "Gathara", "North Kinangop", "Murungaru", "Nyakio",
        "Gathabai",
    ],
    "Kipipiri": ["Geta", "Githioro", "Kipipiri", "Wanjohi"],
    "Ol Kalou": ["Karau", "Kanjuiri Ridge", "Mirangine", "Kaimbaga", "Rurii"],
    "Ol Jorok": [
        "Rumuruti Township", "Githiga", "Marmanet", "Igwamiti", "Salama",
    ],
    "Ndaragwa": ["Leshau", "Pondo", "Shamata", "Ndaragwa"],
    # ── Nyeri ────────────────────────────────────────────────────────────
    "Tetu": ["Dedan Kimathi", "Wamagana", "Aguthi-Gaaki"],
    "Kieni": [
        "Mweiga", "Naromoru/Kiamathaga", "Ngobit", "Kabaru", "Gatarakwa",
    ],
    "Mathira": [
        "Ruguru/Ngandori", "Ragati", "Konyu", "Karatina Town", "Magutu",
    ],
    "Othaya": ["Mahiga", "Iria-ini", "Chinga", "Amboni", "Githiga"],
    "Mukurweini": [
        "Gikondi", "Rugi", "Mukurweini West", "Mukurweini East",
    ],
    "Nyeri Town": ["Ruring'u", "Gatitu/Muruguru", "Kigogoini", "Ruringu"],
    # ── Kirinyaga ────────────────────────────────────────────────────────
    "Mwea": [
        "Mutithi", "Kangai", "Wamumu", "Nyangati", "Gathigiriri", "Tebere",
        "Thiba", "Rwanyange",
    ],
    "Gichugu": ["Kabare", "Baragwi", "Njukiini", "Ngariama", "Karumandi"],
    "Ndia": ["Mukure", "Kiine", "Kariti"],
    "Kirinyaga Central": ["Kerugoya", "Inoi", "Kagio", "Kibutu", "Mukure"],
    # ── Murang'a ─────────────────────────────────────────────────────────
    "Kangema": ["Kanyenyaini", "Muguru", "Rwathia"],
    "Mathioya": ["Kamacharia", "Ichagaki", "Kiru", "Githioro"],
    "Kiharu": [
        "Wangu", "Mugoiri", "Mbiri", "Township", "Murarandia", "Gaturi",
    ],
    "Kigumo": ["Kigumo", "Kahumbu", "Muthithi", "Kinyona"],
    "Maragwa": [
        "Kimorori/Wempa", "Makuyu", "Kambiti", "Maragwa Ridge", "Maragwa",
    ],
    "Kandara": ["Kandara", "Muruka", "Ng'araria", "Ithiru", "Ruchu"],
    "Gatanga": [
        "Ithanga", "Kakuzi/Mitubiri", "Mugumo-ini", "Township", "Gatanga",
        "Kariara",
    ],
    # ── West Pokot ───────────────────────────────────────────────────────
    "Kapenguria": [
        "Kapenguria", "Megendo", "Mnagei", "Riwo", "Siyoi", "Endugh",
        "Senende",
    ],
    "Sigor": ["Lomut", "Weiwei", "Masool", "Suam", "Chepareria"],
    "Kacheliba": ["Kacheliba", "Kodich", "Kanyarkwat", "Kapchok"],
    "Pokot South": ["Sebit", "Tapach", "Lelan", "Sook"],
    # ── Samburu ──────────────────────────────────────────────────────────
    "Samburu West": [
        "Maralal", "Loosuk", "Poro", "Loltulelei", "Suguta Marmar",
    ],
    "Samburu North": [
        "El-Barta", "Nachola", "Ndoto", "Nyiro", "Angata Nanyokie",
    ],
    "Samburu East": ["Waso", "Archer's Post", "Merti", "Garbatulla"],
    # ── Trans Nzoia ──────────────────────────────────────────────────────
    "Kwanza": ["Kwanza", "Keiyo", "Bidii", "Kabocboch"],
    "Endebess": ["Endebess", "Chepchoina", "Matumbei"],
    "Saboti": ["Kinyoro", "Matisi", "Tuwani", "Saboti", "Machewa"],
    "Kiminini": ["Kiminini", "Waitaluk", "Sirende", "Webster", "Nabiswa"],
    "Cherangany": [
        "Sinyerere", "Kaplamai", "Motosiet", "Cherangany/Suwerwa",
        "Sharambatsa/Murpus", "Kapkoi",
    ],
    # ── Uasin Gishu ──────────────────────────────────────────────────────
    "Soy": ["Ziwa", "Huruma", "Kabenes", "Megun", "Kipsomba"],
    "Turbo": ["Tapsagoi", "Kamagut", "Huruma", "Ngenyilel", "Tarakwa"],
    "Moiben": ["Tembelio", "Sergoit", "Karuna/Meibeki", "Moiben", "Kimumu"],
    "Ainabkoi": ["Kapsoya", "Ainabkoi/Olare", "Lemook"],
    "Kapseret": ["Simat/Kapseret", "Kipkenyo", "Ngeria", "Megun", "Langas"],
    "Kesses": [
        "Tarakwa", "Racecourse", "Cheptiret/Kipchamo", "Tulwet/Chuiyat",
    ],
    # ── Elgeyo-Marakwet ──────────────────────────────────────────────────
    "Marakwet East": ["Embobut/Embulot", "Endo", "Sambirir", "Lelan"],
    "Marakwet West": [
        "Sengwer", "Chebiemit", "Moiben/Kuserwo", "Kapyego", "Arror",
    ],
    "Keiyo North": ["Emsoo", "Kamariny", "Kaptarakwa", "Metkei"],
    "Keiyo South": [
        "Kabiemit", "Mosop", "Kipkabus", "Orbem", "Rokocho", "Tambach",
    ],
    # ── Nandi ────────────────────────────────────────────────────────────
    "Tinderet": [
        "Tinderet", "Chemelil", "Sosiot", "Kapsimotwa", "Songhor/Soba",
    ],
    "Aldai": [
        "Kabwareng", "Terik", "Kemeloi-Maraba", "Kobujoi", "Kaptumo-Kaboi",
    ],
    "Nandi Hills": ["Nandi Hills", "Chepkunyuk", "Ol'lessos", "Kapchorua"],
    "Chesumei": [
        "Kosirai", "Lelmokwo/Ngechek", "Chemundu/Kapng'etuny", "Chepterwai",
    ],
    "Emgwen": ["Kilibwoni", "Chepkumia", "Kaptel/Kamoiywo", "Ngechek"],
    "Mosop": ["Kabiyet", "Ndalat", "Sangalo/Kebulonik", "Kabisaga", "Kwanza"],
    # ── Laikipia ─────────────────────────────────────────────────────────
    "Laikipia West": [
        "Ol-Moran", "Rumuruti Township", "Githiga", "Igwamiti", "Salama",
    ],
    "Laikipia East": ["Ngobit", "Tigithi", "Thingithu", "Nanyuki"],
    "Laikipia North": [
        "Sosian", "Segera", "Mukogondo East", "Mukogondo West",
    ],
    # ── Narok ────────────────────────────────────────────────────────────
    "Kilgoris": [
        "Shankoe", "Keyian", "Angata Barikoi", "Lemek", "Ol Chorro Oirowua",
    ],
    "Emurua Dikirr": [
        "Emurua Dikirr", "Kimintet", "Nkareta", "Olposimoru", "Ololmasani",
    ],
    "Narok North": ["Melili", "Narok Town", "Naikarra"],
    "Narok East": ["Mosiro", "Ildamat", "Keekonyokie", "Purko"],
    "Narok South": [
        "Majimoto/Naroosura", "Olkeri", "Narok South", "Ntulele", "Loita",
    ],
    "Narok West": ["Ilkisonko", "Kapse", "Sogoo", "Sampu"],
    # ── Kajiado ──────────────────────────────────────────────────────────
    "Kajiado North": [
        "Purko", "Ongata Rongai", "Nkaimurunya", "Olkeri", "Ngong",
    ],
    "Kajiado Central": [
        "Kajiado Central", "Olkiramatian", "Dalalekutuk", "Imaroro",
    ],
    "Kajiado East": [
        "Mosiro", "Imaroro", "Kajiado East", "Entonet/Lorngete",
    ],
    "Kajiado West": [
        "Keekonyokie", "Iloodokilani", "Magadi", "Ewuaso Oonkidong'i",
        "Mosiro",
    ],
    "Kajiado South": [
        "Entonet/Lorngete", "Mbirikani/Eselenkei", "Kuku", "Rombo", "Kimana",
    ],
    # ── Kericho ──────────────────────────────────────────────────────────
    "Kipkelion East": [
        "Londiani", "Kedowa/Kimulot", "Chepseon", "Tendeno/Sorget",
    ],
    "Kipkelion West": ["Kipkelion", "Chilchila", "Kunyak", "Captain"],
    "Ainamoi": [
        "Ainamoi", "Kapsaos", "Kericho East", "Kericho West", "Kipchebor",
    ],
    "Bureti": ["Litein", "Cheplanget", "Cheboin", "Fort", "Roret"],
    "Belgut": ["Waldai", "Kabianga", "Cheptororiet/Seretut", "Chaik"],
    "Sigowet/Soin": ["Soin", "Kabiyet", "Sigowet", "Soliat"],
    # ── Bomet ────────────────────────────────────────────────────────────
    "Sotik": ["Ndanai/Abosi", "Chemagel", "Kongoni", "Mutarakwa", "Sotik"],
    "Chepalungu": ["Sigor", "Siongiroi", "Merigi", "Kembu", "Longisa"],
    "Bomet East": ["Merigi", "Kembu", "Longisa", "Kipreres", "Chesoen"],
    "Bomet Central": ["Ndaraweta", "Singorwet", "Chesoen", "Mutarakwa"],
    "Konoin": ["Mogogosiek", "Boito", "Embomos", "Kipreres", "Chepchabas"],
    # ── Kakamega ─────────────────────────────────────────────────────────
    "Lugari": ["Lumakanda", "Chekalini", "Chevaywa", "Lugari", "Mautuma"],
    "Likuyani": ["Sango", "Kongoni", "Likuyani", "Nzoia"],
    "Malava": [
        "Shirugu-Mugai", "Butali/Chegulo", "Manda-Shivanga", "Murhanda",
        "Kabras", "Chemuche",
    ],
    "Lurambi": [
        "Sheywe", "Mahiakalo", "Shirere", "Butsotso East", "Butsotso South",
        "Butsotso Central",
    ],
    "Navakholo": [
        "Ingotse-Mathia", "Shinoyi-Shikomari-Esumeyia", "Bunyala West",
        "Bunyala East", "Bunyala Central",
    ],
    "Mumias West": ["Mumias Central", "Mumias North", "Etenje", "Musanda"],
    "Mumias East": [
        "Malaha/Isongo/Makunga", "East Wanga", "Lusheya/Lubinu", "Imenga",
    ],
    "Matungu": ["Koyonzo", "Kholera", "Mayoni", "Namamali", "Khalaba"],
    "Butere": [
        "Marama West", "Marama Central", "Marama North", "Marama South",
        "South Kabras",
    ],
    "Khwisero": ["East Kabras", "Busali", "Khwisero"],
    "Shinyalu": [
        "Isukha North", "Mukangu", "Isukha Central", "Isukha East",
        "Isukha South", "Isukha West",
    ],
    "Ikolomani": [
        "Idakho South", "Idakho East", "Idakho North", "Idakho West",
    ],
    # ── Vihiga ───────────────────────────────────────────────────────────
    "Vihiga": [
        "Lugaga-Wamuluma", "Central Maragoli", "South Maragoli", "Mungoma",
    ],
    "Sabatia": [
        "Wodanga", "Busali", "Sabatia", "Chavakali", "North Maragoli",
        "West Sabatia", "Muhudu",
    ],
    "Hamisi": [
        "Shiru", "Gisambai", "Shamakhokho", "Banja", "Muhudu", "Tambua",
        "Jepkoyai",
    ],
    "Luanda": [
        "Luanda Township", "Wemilabi", "Mwibona", "Luanda South", "Emabungo",
    ],
    "Emuhaya": ["North East Bunyore", "Central Bunyore", "West Bunyore"],
    # ── Bungoma ──────────────────────────────────────────────────────────
    "Mt. Elgon": ["Cheptais", "Chesikaki", "Chepyuk", "Kapkateny", "Kopsiro"],
    "Sirisia": ["Namwela", "Malakisi/South Kulisiru", "Lwandanyi"],
    "Kabuchai": [
        "Kabuchai/Chwele", "West Nalondo", "Bwake/Luuya", "Mukuyuni",
    ],
    "Bumula": [
        "Bumula", "Khasoko", "Kabula", "Kimaeti", "West Bukusu", "Siboti",
    ],
    "Kanduyi": [
        "Bukembe West", "Bukembe East", "Township", "Khalaba", "Musikoma",
        "East Sang'alo", "West Sang'alo",
    ],
    "Webuye East": [
        "Ndivisi", "Maraka", "Bukhayo North/Mishikambu", "Bukhayo East",
        "Bukhayo Central",
    ],
    "Webuye West": ["Misikhu", "Sitikho", "Matulo", "Bokoli"],
    "Kimilili": ["Kimilili", "Maeni", "Kamukuywa", "Kibingei"],
    "Tongaren": [
        "Naitiri/Kabuyefwe", "Milima", "Ndalu/Tabani", "Tongaren", "Mbakalo",
    ],
    # ── Busia ────────────────────────────────────────────────────────────
    "Teso North": [
        "Malaba Central", "Malaba North", "Ang'urai South", "Ang'urai North",
        "Ang'urai East", "Malaba South",
    ],
    "Teso South": [
        "Ang'orom", "Chakol South", "Chakol North", "Amukura West",
        "Amukura East", "Amukura Central",
    ],
    "Nambale": [
        "Nambale Township", "Bukhayo North/Walatsi", "Bukhayo East",
        "Bukhayo Central",
    ],
    "Matayos": [
        "Bukhayo West", "Mayenje", "Matayos South", "Busibwabo", "Burumba",
    ],
    "Butula": [
        "Marachi West", "Kingandole", "Marachi Central", "Marachi East",
        "Marachi North", "Elugulu",
    ],
    "Funyula": [
        "Namboboto-Nambuku", "Nangina", "Ageng'a Nanguba", "Bwiri",
    ],
    "Budalangi": [
        "Bunyala Central", "Bunyala North", "Bunyala West", "Bunyala South",
    ],
    # ── Siaya ────────────────────────────────────────────────────────────
    "Ugenya": ["West Ugenya", "Ukwala", "North Ugenya", "East Ugenya"],
    "Ugunja": ["Sigomere", "Ugunja", "Lunza", "North Ugenya"],
    "Alego Usonga": [
        "Central Alego", "Siaya Township", "North Alego", "South East Alego",
        "Usonga", "West Alego",
    ],
    "Gem": [
        "North Gem", "West Gem", "Central Gem", "Yala Township", "East Gem",
        "South Gem",
    ],
    "Bondo": [
        "Usigu", "Central Sakwa", "West Sakwa", "East Sakwa", "North Sakwa",
        "Bondo Township",
    ],
    "Rarieda": [
        "East Asembo", "West Asembo", "North Uyoma", "South Uyoma",
        "West Uyoma",
    ],
    # ── Homa Bay ─────────────────────────────────────────────────────────
    "Kasipul": [
        "West Kasipul", "Central Kasipul", "Kochia", "South Kasipul",
        "East Kasipul",
    ],
    "Kabondo Kasipul": [
        "Kokwanyo/Kakelo", "Kojwach", "East Kamagak", "West Kamagak",
    ],
    "Karachuonyo": [
        "North Karachuonyo", "Central Karachuonyo", "Kanyaluo", "Kibiri",
        "West Karachuonyo", "Ogembo",
    ],
    "Rangwe": ["East Gem", "West Gem", "Central Gem", "Kochia"],
    "Homa Bay Town": [
        "Homa Bay Central", "Homa Bay Arujo", "Homa Bay West",
        "Homa Bay East",
    ],
    "Ndhiwa": [
        "Kwabwai", "Kanyadoto", "Kanyikela", "Kabuoch North",
        "Kabuoch South", "Kanyamwa Kosewe", "Kanyamwa Kolor",
    ],
    "Suba North": [
        "Mfangano Island", "Gembe East", "Gembe West", "Lambwe",
    ],
    "Suba South": [
        "Kaksingri West", "Gwassi South", "Gwassi North", "Ruma Kaksingri",
    ],
    # ── Migori ───────────────────────────────────────────────────────────
    "Rongo": [
        "North Kadem", "Macalder/Kanyarwanda", "Manga", "Wasimbete",
        "Rongo Central",
    ],
    "Awendo": [
        "North East Kadem", "Suna Central", "God Jope", "Suna East",
    ],
    "Suna East": ["Wiga", "Wasweta II", "God Jope", "Suna Central"],
    "Suna West": ["Wasimbete", "Oluch Kachieng", "Kakrao", "Kwa"],
    "Uriri": [
        "North Kadem", "South Kadem", "Kamagambo Central", "Kamagambo East",
    ],
    "Nyatike": [
        "Kachieng", "Kanyasa", "North Kabuoch", "Karungu", "Muhuru",
        "Macalder/Kanyarwanda",
    ],
    "Kuria West": [
        "Masaba South", "Bukira East", "Bukira Central/Ikerege", "Isibania",
        "Makerero", "Tagare",
    ],
    "Kuria East": [
        "Gokeharaka/Getambwega", "Ntimaru West", "Ntimaru East",
        "Nyamosense/Komosoko",
    ],
    # ── Kisii ────────────────────────────────────────────────────────────
    "Bonchari": ["Bomariba", "Bogiakumu", "Riana", "Bonchari"],
    "South Mugirango": ["Bokeira", "Magwagwa", "Ekerenyo", "Mugirango"],
    "Bomachoge Borabu": [
        "Matongo", "Kiamokama", "Boochi/Tendere", "Bomariba",
    ],
    "Bobasi": [
        "Bobasi Central", "Bobasi Chache", "Masige West", "Masige East",
        "Basi Central", "Nyacheki", "Bobasi Boitangare",
    ],
    "Bomachoge Chache": [
        "Township", "Boochi/Borabu", "Borgichora", "Masige",
    ],
    "Nyaribari Masaba": [
        "Nyaribari Masaba", "Ichuni", "Nyamache", "Gesusu", "Iranda",
    ],
    "Nyaribari Chache": [
        "Getare", "Borabu/Chitago", "Monyerero", "Sensi", "Kisii Central",
    ],
    "Kitutu Chache North": [
        "Kegati", "Municipality", "Monyerero", "Mirambi",
    ],
    "Kitutu Chache South": ["Boikanga", "Gesieka", "Nyatieko", "Marani"],
    # ── Nyamira ──────────────────────────────────────────────────────────
    "Kitutu Masaba": [
        "North Mugirango", "West Mugirango", "Central Mugirango", "Bosamaro",
        "Bonyamatuta", "Township",
    ],
    "West Mugirango": ["Bonyamatuta", "Township", "Bokimai", "Metembe"],
    "North Mugirango": ["Rigoma", "Gakoigo", "Magwagwa", "Ekerenyo"],
    "Borabu": ["Metembe", "Nyansiongo", "Esise", "Bosamaro"],
}

WARD_LOCATIONS = {
    # ── Nairobi ──────────────────────────────────────────────────────────
    "Kitisuru": ["Kitisuru", "Peponi", "Tigoni"],
    "Parklands/Highridge": ["Parklands", "Highridge", "Westlands"],
    "Kangemi": ["Kangemi", "Kinoo", "Regen"],
    "Kilimani": ["Kilimani", "Lavington", "Adams Arcade"],
    "Kawangware": ["Kawangware", "Gitaru", "Kabiria"],
    "Karen": ["Karen", "Langata", "Hardy"],
    "Nairobi West": ["Nairobi West", "Nyayo", "South C"],
    # ── Kisumu ───────────────────────────────────────────────────────────
    "Railways": ["Railways", "Milimani", "Kondele"],
    "Migosi": ["Migosi", "Manyatta", "Nyalenda"],
    "Kondele": ["Kondele", "Obunga", "Nyawita"],
    "Kolwa East": ["Kolwa", "Nyamasaria", "Manyatta A"],
    "Manyatta B": ["Manyatta B", "Nyalenda A", "Obunga"],
    "Nyalenda A": ["Nyalenda A", "Nyalenda B", "Manyatta"],
    "Kolwa Central": ["Kolwa Central", "Kanyakwar"],
    "Central Kisumu": ["Central Kisumu", "Milimani", "Migosi"],
    "South West Kisumu": ["South West Kisumu", "Dunga", "Hippo Point"],
    # ── Mombasa ──────────────────────────────────────────────────────────
    "Tudor": ["Tudor", "Mishomoroni", "Mkadara"],
    "Tononoka": ["Tononoka", "Kizingo", "Ganjoni"],
    "Bamburi": ["Bamburi", "Mtopanga", "Mwakirunge"],
    "Kongowea": ["Kongowea", "Kadzandani", "Mkomani"],
    "Mtongwe": ["Mtongwe", "Shika Adabu", "Likoni"],
    # ── Nakuru ───────────────────────────────────────────────────────────
    "Biashara": ["Biashara", "Kivumbini", "Afraha"],
    "Kivumbini": ["Kivumbini", "Flamingo", "Section 58"],
    "Naivasha East": ["Naivasha East", "Kihoto", "Kamere"],
    "Gilgil": ["Gilgil", "Elementaita", "Mbaruk"],
    "Mariashoni": ["Mariashoni", "Elburgon", "Molo Town"],
    # ── Kiambu ───────────────────────────────────────────────────────────
    "Kamenu": ["Kamenu", "Hospital", "Thika Town"],
    "Gitothua": ["Gitothua", "Biashara", "Gatongora"],
    "Murera": ["Murera", "Witeithie", "Kalimoni"],
    # ── Baringo ──────────────────────────────────────────────────────────
    "Kabarnet": ["Kabarnet", "Sacho", "Tenges"],
    "Tirioko": ["Tirioko", "Kolowa", "Ribkwo"],
    "Silale": ["Silale", "Loiyamorock", "Tangulbei"],
    "Emining": ["Emining", "Rongoa", "Kisanana"],
    # ── Turkana ──────────────────────────────────────────────────────────
    "Lodwar Township": ["Lodwar", "Napetet", "Lolupe"],
    "Kakuma": ["Kakuma", "Lokichoggio", "Kalobeyei"],
    "Lokichar": ["Lokichar", "Kerio", "Nakwamoru"],
    "Kalokol": ["Kalokol", "Eliye Springs", "Ferguson Gulf"],
}

LOCATION_SUBLOCATION = {
    # ── Nairobi ──────────────────────────────────────────────────────────
    "Kitisuru": ["Kitisuru A", "Kitisuru B", "Peponi"],
    "Parklands": [
        "1st Avenue", "2nd Avenue", "3rd Avenue",
        "4th Avenue", "5th Avenue", "6th Avenue",
    ],
    "Kangemi": ["Kangemi A", "Kangemi B", "Lower Kangemi"],
    "Kilimani": ["Kilimani", "Lavington", "Valley Arcade"],
    "Kawangware": ["Kawangware A", "Kawangware B", "Gitaru"],
    "Karen": ["Karen A", "Karen B", "Karen C"],
    # ── Kisumu ───────────────────────────────────────────────────────────
    "Kolwa": ["Kolwa A", "Kolwa B", "Upper Kolwa"],
    "Nyamasaria": ["Nyamasaria A", "Nyamasaria B"],
    "Manyatta A": ["Manyatta A1", "Manyatta A2"],
    "Nyalenda A": ["Nyalenda A1", "Nyalenda A2"],
    "Nyalenda B": ["Nyalenda B1", "Nyalenda B2"],
    "Obunga": ["Obunga A", "Obunga B", "Lower Obunga"],
    "Kondele": ["Kondele A", "Kondele B", "Upper Kondele"],
    "Milimani": ["Milimani", "Upper Milimani"],
    "Migosi": ["Migosi A", "Migosi B"],
    # ── Mombasa ──────────────────────────────────────────────────────────
    "Tudor": ["Tudor A", "Tudor B", "Mishomoroni"],
    "Tononoka": ["Tononoka A", "Tononoka B"],
    "Bamburi": ["Bamburi A", "Bamburi B", "Mtopanga"],
    "Kongowea": ["Kongowea A", "Kongowea B"],
    "Mtongwe": ["Mtongwe A", "Mtongwe B"],
    # ── Nakuru ───────────────────────────────────────────────────────────
    "Biashara": ["Biashara A", "Biashara B"],
    "Kivumbini": ["Kivumbini A", "Kivumbini B"],
    "Naivasha East": ["Naivasha East A", "Naivasha East B"],
    "Gilgil": ["Gilgil A", "Gilgil B", "Elementaita"],
    "Mariashoni": ["Mariashoni A", "Mariashoni B"],
    # ── Baringo ──────────────────────────────────────────────────────────
    "Kabarnet": ["Kabarnet A", "Kabarnet B", "Sacho"],
    "Tirioko": ["Tirioko A", "Tirioko B"],
    "Silale": ["Silale A", "Silale B"],
    # ── Turkana ──────────────────────────────────────────────────────────
    "Lodwar": ["Lodwar A", "Lodwar B", "Napetet"],
    "Kakuma": ["Kakuma A", "Kakuma B", "Kalobeyei"],
    "Lokichar": ["Lokichar A", "Lokichar B"],
    "Kalokol": ["Kalokol A", "Kalokol B"],
}

# Wards without curated location data get predictable "<ward> A/B" entries
# (project decision) so the picker's Location level always has options.
# setdefault keeps every curated list above authoritative.
for _wards in CONSTITUENCY_WARDS.values():
    for _ward in _wards:
        WARD_LOCATIONS.setdefault(_ward, [f"{_ward} A", f"{_ward} B"])
