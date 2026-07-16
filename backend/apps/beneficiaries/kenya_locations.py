"""
Kenya administrative-boundary reference data for the cascading location
picker (county → constituency → ward → location → sub-location), mirroring
the eCitizen hierarchy.

Coverage:
- KENYA_COUNTIES: all 47 counties.
- COUNTY_CONSTITUENCIES: the complete, real constituency list for every
  county (290 constituencies, per IEBC delimitation).
- CONSTITUENCY_WARDS: real ward lists for the counties that appear in the
  demo/seed data and the major urban counties (Nairobi, Mombasa, Kisumu,
  Nakuru, Kiambu, Baringo, Turkana).
- WARD_LOCATIONS / LOCATION_SUBLOCATION: locations and sub-locations for a
  representative subset of the wards above (project-supplied data).

Any level without data for a given parent returns an empty list from the
API and the client renders that dropdown as skippable — every level below
county is optional on the Beneficiary model.
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
