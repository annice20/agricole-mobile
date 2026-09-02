class Programme {
  final String nom;

  Programme({required this.nom});

  factory Programme.fromJson(Map<String, dynamic> json) {
    return Programme(nom: json['nom'] ?? 'Programme Général');
  }
}

class DemandeAide {
  final Programme? programme;

  DemandeAide({this.programme});

  factory DemandeAide.fromJson(Map<String, dynamic> json) {
    return DemandeAide(
      programme: json['programme'] != null
          ? Programme.fromJson(json['programme'])
          : null,
    );
  }
}

class Aide {
  final String id;
  final DemandeAide? demandeAide;
  final double montant;
  final String? description;
  final DateTime? dateDistribution;

  Aide({
    required this.id,
    this.demandeAide,
    required this.montant,
    this.description,
    this.dateDistribution,
  });

  factory Aide.fromJson(Map<String, dynamic> json) {
    return Aide(
      id: json['id']?.toString() ?? '',
      demandeAide: json['demandeAide'] != null
          ? DemandeAide.fromJson(json['demandeAide'])
          : null,
      montant: double.tryParse(json['montant']?.toString() ?? '0') ?? 0.0,
      description: json['description'],
      dateDistribution: json['dateDistribution'] != null
          ? DateTime.tryParse(json['dateDistribution'].toString())
          : null,
    );
  }
}
