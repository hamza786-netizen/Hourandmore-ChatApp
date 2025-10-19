import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/listing.dart';

class ListingService {
  static final ListingService instance = ListingService._init();
  
  static const String _baseUrl = 'https://staging.hourandmore.sa/api/v1';
  static const String _listingsEndpoint = '/listings';
  
  ListingService._init();

  Future<List<Listing>> getListings() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl$_listingsEndpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        
        if (data.containsKey('data') && data['data'] is List) {
          final List<dynamic> listingsJson = data['data'];
          final List<Listing> listings = listingsJson
              .map((json) => Listing.fromJson(json))
              .toList();
          
          return listings;
        } else {
          throw Exception('Invalid API response format');
        }
      } else {
        throw Exception('Failed to load listings: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Listing>> searchListings({
    String? query,
    String? location,
    double? minPrice,
    double? maxPrice,
    int? minCapacity,
    bool? isFeatured,
    bool? isInsurance,
    String? status,
  }) async {
    try {
      final allListings = await getListings();
      
      List<Listing> filteredListings = allListings;

      if (query != null && query.isNotEmpty) {
        filteredListings = filteredListings.where((listing) {
          return listing.title.toLowerCase().contains(query.toLowerCase()) ||
                 listing.description.toLowerCase().contains(query.toLowerCase()) ||
                 listing.location.toLowerCase().contains(query.toLowerCase());
        }).toList();
      }

      if (location != null && location.isNotEmpty) {
        filteredListings = filteredListings.where((listing) {
          return listing.location.toLowerCase().contains(location.toLowerCase());
        }).toList();
      }

      if (minPrice != null) {
        filteredListings = filteredListings.where((listing) {
          final price = double.tryParse(listing.pricePerHour) ?? 0.0;
          return price >= minPrice;
        }).toList();
      }

      if (maxPrice != null) {
        filteredListings = filteredListings.where((listing) {
          final price = double.tryParse(listing.pricePerHour) ?? 0.0;
          return price <= maxPrice;
        }).toList();
      }

      if (minCapacity != null) {
        filteredListings = filteredListings.where((listing) {
          return listing.capacity >= minCapacity;
        }).toList();
      }

      if (isFeatured != null) {
        filteredListings = filteredListings.where((listing) {
          return listing.isFeatured == isFeatured;
        }).toList();
      }

      if (isInsurance != null) {
        filteredListings = filteredListings.where((listing) {
          return listing.isInsurance == isInsurance;
        }).toList();
      }

      if (status != null && status.isNotEmpty) {
        filteredListings = filteredListings.where((listing) {
          return listing.status.toLowerCase() == status.toLowerCase();
        }).toList();
      }

      return filteredListings;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Listing>> getFeaturedListings() async {
    try {
      final allListings = await getListings();
      return allListings.where((listing) => listing.isFeatured).toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Listing>> getListingsByCategory(int categoryId) async {
    try {
      final allListings = await getListings();
      return allListings.where((listing) => listing.categoryId == categoryId).toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<Listing?> getListingById(int id) async {
    try {
      final allListings = await getListings();
      return allListings.firstWhere(
        (listing) => listing.id == id,
        orElse: () => throw Exception('Listing not found'),
      );
    } catch (e) {
      return null;
    }
  }
}