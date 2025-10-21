class Listing {
  final int id;
  final int userId;
  final int categoryId;
  final String title;
  final String description;
  final String pricePerHour;
  final String? pricePerDay;
  final String? licenseNumber;
  final String location;
  final String cancellationPolicy;
  final String accessInformation;
  final String status;
  final int capacity;
  final String capacityType;
  final bool isDiscount;
  final bool isDayBookingAllowed;
  final String discountPercentage;
  final bool isInsurance;
  final double insurancePrice;
  final bool isFeatured;
  final double latitude;
  final double longitude;
  final int minBookingHours;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ListingImage> images;
  final List<ListingAttribute> attributes;
  final ListingHost host;
  final int activeBookings;
  final double totalEarnings;
  final List<String> unavailableDates;
  final double averageRating;
  final int reviewCount;
  final List<dynamic> reviews;

  Listing({
    required this.id,
    required this.userId,
    required this.categoryId,
    required this.title,
    required this.description,
    required this.pricePerHour,
    this.pricePerDay,
    this.licenseNumber,
    required this.location,
    required this.cancellationPolicy,
    required this.accessInformation,
    required this.status,
    required this.capacity,
    required this.capacityType,
    required this.isDiscount,
    required this.isDayBookingAllowed,
    required this.discountPercentage,
    required this.isInsurance,
    required this.insurancePrice,
    required this.isFeatured,
    required this.latitude,
    required this.longitude,
    required this.minBookingHours,
    required this.createdAt,
    required this.updatedAt,
    required this.images,
    required this.attributes,
    required this.host,
    required this.activeBookings,
    required this.totalEarnings,
    required this.unavailableDates,
    required this.averageRating,
    required this.reviewCount,
    required this.reviews,
  });

  factory Listing.fromJson(Map<String, dynamic> json) {
    return Listing(
      id: _parseInt(json['id']) ?? 0,
      userId: _parseInt(json['user_id']) ?? 0,
      categoryId: _parseInt(json['category_id']) ?? 0,
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      pricePerHour: json['price_per_hour']?.toString() ?? '0.00',
      pricePerDay: json['price_per_day']?.toString(),
      licenseNumber: json['license_number']?.toString(),
      location: json['location']?.toString() ?? '',
      cancellationPolicy: json['cancellation_policy']?.toString() ?? '',
      accessInformation: json['access_information']?.toString() ?? '',
      status: json['status']?.toString() ?? 'inactive',
      capacity: _parseInt(json['capacity']) ?? 1,
      capacityType: json['capacity_type']?.toString() ?? 'person',
      isDiscount: _parseInt(json['is_discount']) == 1,
      isDayBookingAllowed: _parseInt(json['is_day_booking_allowed']) == 1,
      discountPercentage: json['discount_percentage']?.toString() ?? '0.00',
      isInsurance: _parseInt(json['is_insurance']) == 1,
      insurancePrice: _parseDouble(json['insurance_price']) ?? 0.0,
      isFeatured: _parseInt(json['is_featured']) == 1,
      latitude: _parseDouble(json['latitude']) ?? 0.0,
      longitude: _parseDouble(json['longitude']) ?? 0.0,
      minBookingHours: _parseInt(json['min_booking_hours']) ?? 1,
      createdAt: _parseDateTime(json['created_at']) ?? DateTime.now(),
      updatedAt: _parseDateTime(json['updated_at']) ?? DateTime.now(),
      images: (json['images'] as List<dynamic>?)
          ?.map((image) => ListingImage.fromJson(image))
          .toList() ?? [],
      attributes: (json['attributes'] as List<dynamic>?)
          ?.map((attr) => ListingAttribute.fromJson(attr))
          .toList() ?? [],
      host: ListingHost.fromJson(json['host'] ?? {}),
      activeBookings: _parseInt(json['activeBookings']) ?? 0,
      totalEarnings: _parseDouble(json['totalEarnings']) ?? 0.0,
      unavailableDates: (json['unavailable_dates'] as List<dynamic>?)
          ?.map((date) => date.toString())
          .toList() ?? [],
      averageRating: _parseDouble(json['averageRating']) ?? 0.0,
      reviewCount: _parseInt(json['reviewCount']) ?? 0,
      reviews: json['reviews'] ?? [],
    );
  }

  // Helper methods for safe type conversion
  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    if (value is double) return value.toInt();
    return null;
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'category_id': categoryId,
      'title': title,
      'description': description,
      'price_per_hour': pricePerHour,
      'price_per_day': pricePerDay,
      'license_number': licenseNumber,
      'location': location,
      'cancellation_policy': cancellationPolicy,
      'access_information': accessInformation,
      'status': status,
      'capacity': capacity,
      'capacity_type': capacityType,
      'is_discount': isDiscount ? 1 : 0,
      'is_day_booking_allowed': isDayBookingAllowed ? 1 : 0,
      'discount_percentage': discountPercentage,
      'is_insurance': isInsurance ? 1 : 0,
      'insurance_price': insurancePrice,
      'is_featured': isFeatured ? 1 : 0,
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
      'min_booking_hours': minBookingHours,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'images': images.map((image) => image.toJson()).toList(),
      'attributes': attributes.map((attr) => attr.toJson()).toList(),
      'host': host.toJson(),
      'activeBookings': activeBookings,
      'totalEarnings': totalEarnings,
      'unavailable_dates': unavailableDates,
      'averageRating': averageRating,
      'reviewCount': reviewCount,
      'reviews': reviews,
    };
  }
}

class ListingImage {
  final int id;
  final String url;
  final bool isFeatured;
  final DateTime? createdAt;

  ListingImage({
    required this.id,
    required this.url,
    required this.isFeatured,
    this.createdAt,
  });

  factory ListingImage.fromJson(Map<String, dynamic> json) {
    return ListingImage(
      id: Listing._parseInt(json['id']) ?? 0,
      url: json['url']?.toString() ?? '',
      isFeatured: (json['is_featured']?.toString() ?? '0') == '1',
      createdAt: Listing._parseDateTime(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'url': url,
      'is_featured': isFeatured ? '1' : '0',
      'created_at': createdAt?.toIso8601String(),
    };
  }
}

class ListingAttribute {
  final int id;
  final String name;
  final int? categoryId;
  final int quantity;
  final List<ListingFacility> facilities;

  ListingAttribute({
    required this.id,
    required this.name,
    this.categoryId,
    required this.quantity,
    required this.facilities,
  });

  factory ListingAttribute.fromJson(Map<String, dynamic> json) {
    return ListingAttribute(
      id: Listing._parseInt(json['id']) ?? 0,
      name: json['name']?.toString() ?? '',
      categoryId: Listing._parseInt(json['category_id']),
      quantity: Listing._parseInt(json['quantity']) ?? 1,
      facilities: (json['facilities'] as List<dynamic>?)
          ?.map((facility) => ListingFacility.fromJson(facility))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category_id': categoryId,
      'quantity': quantity,
      'facilities': facilities.map((facility) => facility.toJson()).toList(),
    };
  }
}

class ListingFacility {
  final int id;
  final String name;

  ListingFacility({
    required this.id,
    required this.name,
  });

  factory ListingFacility.fromJson(Map<String, dynamic> json) {
    return ListingFacility(
      id: Listing._parseInt(json['id']) ?? 0,
      name: json['name']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }
}

class ListingHost {
  final int id;
  final String name;
  final String email;
  final String phone;
  final String? fcmToken;
  final String? usrId;
  final String? usrGender;
  final String profileImageUrl;
  final double rating;
  final int reviewCount;
  final bool isVerified;
  final String responseRate;
  final DateTime joinDate;

  ListingHost({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    this.fcmToken,
    this.usrId,
    this.usrGender,
    required this.profileImageUrl,
    required this.rating,
    required this.reviewCount,
    required this.isVerified,
    required this.responseRate,
    required this.joinDate,
  });

  factory ListingHost.fromJson(Map<String, dynamic> json) {
    return ListingHost(
      id: Listing._parseInt(json['id']) ?? 0,
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      fcmToken: json['fcm_token']?.toString(),
      usrId: json['usr_id']?.toString(),
      usrGender: json['usr_gender']?.toString(),
      profileImageUrl: json['profile_image_url']?.toString() ?? '',
      rating: Listing._parseDouble(json['rating']) ?? 0.0,
      reviewCount: Listing._parseInt(json['review_count']) ?? 0,
      isVerified: json['is_verified'] == true || json['is_verified'] == 1,
      responseRate: json['response_rate']?.toString() ?? '0%',
      joinDate: Listing._parseDateTime(json['join_date']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'fcm_token': fcmToken,
      'usr_id': usrId,
      'usr_gender': usrGender,
      'profile_image_url': profileImageUrl,
      'rating': rating,
      'review_count': reviewCount,
      'is_verified': isVerified,
      'response_rate': responseRate,
      'join_date': joinDate.toIso8601String(),
    };
  }
}
