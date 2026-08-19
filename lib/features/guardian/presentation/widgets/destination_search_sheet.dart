import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/radius.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/widgets/glass_card.dart';

class PlaceSearchResult {
  const PlaceSearchResult({
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
    required this.icon,
  });

  final String name;
  final String address;
  final double lat;
  final double lng;
  final IconData icon;
}

class DestinationSearchSheet extends StatefulWidget {
  const DestinationSearchSheet({
    super.key,
    required this.onSelectDestination,
    required this.onClose,
  });

  final void Function(double lat, double lng, String name, String mode) onSelectDestination;
  final VoidCallback onClose;

  @override
  State<DestinationSearchSheet> createState() => _DestinationSearchSheetState();
}

class _DestinationSearchSheetState extends State<DestinationSearchSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedMode = 'DRIVE';
  bool _isSearching = false;
  List<PlaceSearchResult> _searchResults = [];
  Timer? _debounceTimer;

  static const List<PlaceSearchResult> _curatedDestinations = [
    PlaceSearchResult(
      name: 'Tambaram',
      address: 'Tambaram, Chennai, Tamil Nadu',
      lat: 12.9249,
      lng: 80.1000,
      icon: Icons.location_city,
    ),
    PlaceSearchResult(
      name: 'Tambaram Railway Station',
      address: 'GST Road, East Tambaram, Chennai',
      lat: 12.9279,
      lng: 80.1215,
      icon: Icons.train,
    ),
    PlaceSearchResult(
      name: 'Tambaram Bus Stand',
      address: 'West Tambaram, Chennai',
      lat: 12.9260,
      lng: 80.1170,
      icon: Icons.directions_bus,
    ),
    PlaceSearchResult(
      name: 'Besant Nagar Beach',
      address: 'Besant Nagar, Chennai',
      lat: 13.0001,
      lng: 80.2667,
      icon: Icons.beach_access,
    ),
    PlaceSearchResult(
      name: 'Marina Beach Promenade',
      address: 'Kamarajar Salai, Chennai',
      lat: 13.0556,
      lng: 80.2821,
      icon: Icons.waves,
    ),
    PlaceSearchResult(
      name: 'Chennai Central Railway Station',
      address: 'Park Town, Chennai',
      lat: 13.0827,
      lng: 80.2756,
      icon: Icons.train,
    ),
    PlaceSearchResult(
      name: 'Phoenix Marketcity',
      address: 'Velachery, Chennai',
      lat: 12.9912,
      lng: 80.2178,
      icon: Icons.shopping_bag,
    ),
    PlaceSearchResult(
      name: 'T. Nagar Commercial Hub',
      address: 'Panagal Park, T. Nagar, Chennai',
      lat: 13.0412,
      lng: 80.2345,
      icon: Icons.storefront,
    ),
    PlaceSearchResult(
      name: 'Guindy Metro Station',
      address: 'GST Road, Guindy, Chennai',
      lat: 13.0078,
      lng: 80.2134,
      icon: Icons.subway,
    ),
    PlaceSearchResult(
      name: 'Chennai International Airport',
      address: 'Meenambakkam, Chennai',
      lat: 12.9941,
      lng: 80.1709,
      icon: Icons.flight,
    ),
    PlaceSearchResult(
      name: 'Anna Nagar Tower Park',
      address: 'Anna Nagar, Chennai',
      lat: 13.0856,
      lng: 80.2145,
      icon: Icons.park,
    ),
    PlaceSearchResult(
      name: 'Koyambedu CMBT',
      address: 'Koyambedu, Chennai',
      lat: 13.0673,
      lng: 80.1989,
      icon: Icons.directions_bus_filled,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _searchResults = List.from(_curatedDestinations);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = List.from(_curatedDestinations);
      });
      return;
    }

    // Filter curated locally first for instant feedback
    final localMatches = _curatedDestinations.where((d) =>
        d.name.toLowerCase().contains(trimmed.toLowerCase()) ||
        d.address.toLowerCase().contains(trimmed.toLowerCase())).toList();

    setState(() {
      _searchResults = localMatches;
      _isSearching = true;
    });

    // Debounce online geocoding query
    _debounceTimer = Timer(const Duration(milliseconds: 600), () {
      _performOnlineGeocode(trimmed);
    });
  }

  Future<void> _performOnlineGeocode(String query) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?format=json&q=${Uri.encodeComponent(query)}+Chennai&limit=6',
      );
      final response = await http.get(
        url,
        headers: {'User-Agent': 'GuardianAI-SafetySuite/1.2'},
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200 && mounted) {
        final List data = jsonDecode(response.body);
        final dynamicResults = <PlaceSearchResult>[];

        for (final item in data) {
          final lat = double.tryParse(item['lat']?.toString() ?? '');
          final lon = double.tryParse(item['lon']?.toString() ?? '');
          final displayName = item['display_name'] as String? ?? query;

          if (lat != null && lon != null) {
            final parts = displayName.split(',');
            final name = parts.first.trim();
            final address = parts.length > 1 ? parts.sublist(1).take(3).join(',').trim() : displayName;

            dynamicResults.add(
              PlaceSearchResult(
                name: name,
                address: address,
                lat: lat,
                lng: lon,
                icon: Icons.location_on,
              ),
            );
          }
        }

        // Combine local matches and dynamic geocode results (avoiding exact coordinate duplicates)
        final combined = <PlaceSearchResult>[..._searchResults];
        for (final res in dynamicResults) {
          if (!combined.any((c) => (c.lat - res.lat).abs() < 0.001 && (c.lng - res.lng).abs() < 0.001)) {
            combined.add(res);
          }
        }

        setState(() {
          _searchResults = combined;
          _isSearching = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHighest.withValues(alpha: 0.96),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.4)),
      ),
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: AppRadius.borderFull,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Text('Where to safely navigate?', style: AppTextStyles.headlineMd),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.onSurfaceVariant),
                onPressed: widget.onClose,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Travel Mode Toggle (Drive vs Walk)
          Row(
            children: [
              ChoiceChip(
                label: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.directions_car, size: 16),
                    SizedBox(width: 6),
                    Text('Drive'),
                  ],
                ),
                selected: _selectedMode == 'DRIVE',
                onSelected: (val) {
                  if (val) setState(() => _selectedMode = 'DRIVE');
                },
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.directions_walk, size: 16),
                    SizedBox(width: 6),
                    Text('Walk'),
                  ],
                ),
                selected: _selectedMode == 'WALK',
                onSelected: (val) {
                  if (val) setState(() => _selectedMode = 'WALK');
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Search Field
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            borderRadius: AppRadius.borderFull,
            child: TextField(
              controller: _searchController,
              style: AppTextStyles.bodyMd,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search destination (e.g. Tambaram, Airport)...',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                icon: _isSearching
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryPulse),
                      )
                    : const Icon(AppIcons.search, color: AppColors.primaryPulse),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: AppColors.onSurfaceVariant, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          Text(
            _searchController.text.isEmpty
                ? 'POPULAR CHENNAI DESTINATIONS'
                : 'SEARCH RESULTS (${_searchResults.length})',
            style: AppTextStyles.labelSm.copyWith(letterSpacing: 0.8),
          ),
          const SizedBox(height: AppSpacing.sm),

          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: _searchResults.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Text(
                        'No matches found for "${_searchController.text}". Try another address or area.',
                        style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: _searchResults.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, idx) {
                      final dest = _searchResults[idx];
                      return InkWell(
                        onTap: () {
                          widget.onSelectDestination(
                            dest.lat,
                            dest.lng,
                            dest.name,
                            _selectedMode,
                          );
                        },
                        borderRadius: AppRadius.borderLg,
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLowest.withValues(alpha: 0.7),
                            borderRadius: AppRadius.borderLg,
                            border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryPulse.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(dest.icon, color: AppColors.primaryPulse, size: 18),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(dest.name, style: AppTextStyles.bodyMd.copyWith(fontWeight: FontWeight.w700)),
                                    Text(
                                      dest.address,
                                      style: AppTextStyles.labelSm.copyWith(color: AppColors.onSurfaceVariant),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.onSurfaceVariant),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
