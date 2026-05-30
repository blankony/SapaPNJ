import 'dart:io';
import '../../services/app_cache_manager.dart';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../../services/overlay_service.dart';
import '../../services/gcs_service.dart';
import '../../services/api_service.dart';
import '../../main.dart';
import '../../theme/app_theme.dart';

class CommunitySettingsScreen extends StatefulWidget {
  final String communityId;
  final Map<String, dynamic> communityData;
  final bool isOwner;
  final bool isAdmin;

  const CommunitySettingsScreen({
    super.key,
    required this.communityId,
    required this.communityData,
    required this.isOwner,
    required this.isAdmin,
  });

  @override
  State<CommunitySettingsScreen> createState() => _CommunitySettingsScreenState();
}

class _CommunitySettingsScreenState extends State<CommunitySettingsScreen> with SingleTickerProviderStateMixin {
  final GcsService _cloudinaryService = GcsService();
  late TabController _tabController;

  late TextEditingController _nameController;
  late TextEditingController _descController;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  bool _isLoading = true;
  bool _isDeleting = false;
  bool _isUploadingImage = false;
  bool _isSavingInfo = false;
  bool _allowMemberPosts = false;

  Map<String, dynamic>? _communityData;
  List<Map<String, dynamic>> _members = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _allowMemberPosts = widget.communityData['allowMemberPosts'] ?? widget.communityData['allow_member_posts'] ?? false;
    _nameController = TextEditingController(text: widget.communityData['name'] ?? '');
    _descController = TextEditingController(text: widget.communityData['description'] ?? '');

    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _descController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final data = await ApiService().getCommunity(widget.communityId);
      final membersList = await ApiService().getCommunityMembers(widget.communityId);
      if (mounted) {
        setState(() {
          _communityData = data;
          _members = membersList;
          if (data != null) {
            _allowMemberPosts = data['allow_member_posts'] == 1 || data['allow_member_posts'] == true;
            _nameController.text = data['name'] ?? '';
            _descController.text = data['description'] ?? '';
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        OverlayService().showTopNotification(context, "Error loading settings", Icons.error, (){}, color: Colors.red);
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveInfo() async {
    if (_nameController.text.trim().isEmpty) {
      OverlayService().showTopNotification(context, "Name cannot be empty", Icons.warning, (){}, color: Colors.orange);
      return;
    }

    setState(() => _isSavingInfo = true);
    FocusScope.of(context).unfocus();

    try {
      await ApiService().updateCommunity(widget.communityId, {
        'name': _nameController.text.trim(),
        'description': _descController.text.trim(),
      });
      if (mounted) OverlayService().showTopNotification(context, "Info Updated", Icons.check_circle, (){}, color: Colors.green);
      _loadData();
    } catch (e) {
      if (mounted) OverlayService().showTopNotification(context, "Update Failed", Icons.error, (){}, color: Colors.red);
    } finally {
      if (mounted) setState(() => _isSavingInfo = false);
    }
  }

  Future<void> _updatePermission(bool value) async {
    setState(() => _allowMemberPosts = value);
    try {
      await ApiService().updateCommunity(widget.communityId, {
        'allow_member_posts': value
      });
    } catch (e) {
      setState(() => _allowMemberPosts = !value);
    }
  }

  Future<void> _pickAndUploadImage({required bool isBanner, required ImageSource source}) async {
    final picker = ImagePicker();
    try {
      final XFile? pickedFile = await picker.pickImage(maxWidth: 1920, maxHeight: 1920, source: source, imageQuality: 70);
      if (pickedFile == null) return;

      final croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        compressQuality: 70,
        aspectRatio: isBanner
            ? CropAspectRatio(ratioX: 3, ratioY: 1)
            : CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: isBanner ? 'Crop Banner' : 'Crop Icon',
            toolbarColor: SisapaTheme.blue,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: isBanner ? CropAspectRatioPreset.ratio3x2 : CropAspectRatioPreset.square,
            lockAspectRatio: true,
          ),
          IOSUiSettings(title: isBanner ? 'Crop Banner' : 'Crop Icon', aspectRatioLockEnabled: true),
        ],
      );

      if (croppedFile == null) return;
      setState(() => _isUploadingImage = true);
      final String? downloadUrl = await _cloudinaryService.uploadImage(File(croppedFile.path));

      if (downloadUrl != null) {
        final Map<String, dynamic> update = isBanner
            ? {'banner_image_url': downloadUrl}
            : {'image_url': downloadUrl};

        await ApiService().updateCommunity(widget.communityId, update);
        if (mounted) {
          OverlayService().showTopNotification(context, "Updated successfully!", Icons.check_circle, (){}, color: Colors.green);
          _loadData();
        }
      }
    } catch (e) {
      if (mounted) OverlayService().showTopNotification(context, "Error: $e", Icons.error, (){}, color: Colors.red);
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  void _showImageSourceSelection({required bool isBanner}) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              SizedBox(height: 16),
              ListTile(
                leading: Icon(Icons.camera_alt, color: SisapaTheme.blue),
                title: Text("Take Photo"),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUploadImage(isBanner: isBanner, source: ImageSource.camera);
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_library, color: SisapaTheme.blue),
                title: Text("Choose from Gallery"),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUploadImage(isBanner: isBanner, source: ImageSource.gallery);
                },
              ),
              SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Future<void> _updateRoleAccess(String targetUid, String action) async {
    try {
      bool success = false;
      if (action == 'kick') {
        success = await ApiService().removeCommunityMember(widget.communityId, targetUid);
      } else {
        String role = 'follower';
        if (action == 'make_admin') {
          role = 'admin';
        } else if (action == 'make_editor') {
          role = 'editor';
        } else if (action == 'make_mod') {
          role = 'moderator';
        }
        success = await ApiService().updateMemberRole(widget.communityId, targetUid, role);
      }

      if (success) {
        OverlayService().showTopNotification(context, "Permissions Updated", Icons.check_circle, (){});
        _loadData();
      } else {
        throw Exception("Failed to update role");
      }
    } catch (e) {
      OverlayService().showTopNotification(context, "Action failed", Icons.error, (){}, color: Colors.red);
    }
  }

  Future<void> _deleteCommunity() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Delete Channel?"),
        content: Text("Are you sure? This will delete the identity and all data permanently."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: Text("Delete")),
        ],
      ),
    );

    if (confirm != true) return;
    setState(() => _isDeleting = true);

    try {
      await ApiService().deleteCommunity(widget.communityId);
      if (mounted) {
        OverlayService().showTopNotification(context, "Channel Deleted", Icons.delete_forever, (){});
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDeleting = false);
        OverlayService().showTopNotification(context, "Failed to delete", Icons.error, (){}, color: Colors.red);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text("Settings & Roles")),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final String ownerId = _communityData?['owner_uid'] ?? '';
    final String imageUrl = _communityData?['image_url'] ?? '';
    final String bannerUrl = _communityData?['banner_image_url'] ?? '';

    return Scaffold(
      appBar: AppBar(title: Text("Settings & Roles")),
      body: Column(
        children: [
          SizedBox(
            height: 180,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                GestureDetector(
                  onTap: (widget.isOwner || widget.isAdmin) ? () => _showImageSourceSelection(isBanner: true) : null,
                  child: Container(
                    width: double.infinity,
                    height: 120,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[800] : Colors.grey[300],
                      image: bannerUrl.isNotEmpty
                          ? DecorationImage(image: CachedNetworkImageProvider(bannerUrl, cacheManager: AppCacheManager.instance), fit: BoxFit.cover)
                          : null,
                    ),
                    child: bannerUrl.isEmpty && (widget.isOwner || widget.isAdmin)
                        ? Center(child: Icon(Icons.add_a_photo, color: Colors.white70))
                        : null,
                  ),
                ),

                Positioned(
                  bottom: 0,
                  left: 20,
                  child: GestureDetector(
                    onTap: (widget.isOwner || widget.isAdmin) ? () => _showImageSourceSelection(isBanner: false) : null,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: theme.scaffoldBackgroundColor, width: 4),
                      ),
                      child: CircleAvatar(
                        radius: 40,
                        backgroundImage: imageUrl.isNotEmpty ? CachedNetworkImageProvider(imageUrl, cacheManager: AppCacheManager.instance) : null,
                        child: imageUrl.isEmpty ? Icon(Icons.groups, size: 40) : null,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          TabBar(
            controller: _tabController,
            labelColor: SisapaTheme.blue,
            unselectedLabelColor: Colors.grey,
            tabs: const [Tab(text: "General"), Tab(text: "Members & Roles")],
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // TAB 1: GENERAL (Editable Info)
                ListView(
                  padding: EdgeInsets.all(16),
                  children: [
                    Text("Community Name", style: TextStyle(fontWeight: FontWeight.bold, color: theme.hintColor)),
                    SizedBox(height: 8),
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                    ),

                    SizedBox(height: 16),

                    Text("Description", style: TextStyle(fontWeight: FontWeight.bold, color: theme.hintColor)),
                    SizedBox(height: 8),
                    TextField(
                      controller: _descController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        alignLabelWithHint: true,
                      ),
                    ),

                    SizedBox(height: 16),

                    if (widget.isOwner || widget.isAdmin)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSavingInfo ? null : _saveInfo,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: SisapaTheme.blue,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _isSavingInfo
                              ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : Text("Save Changes"),
                        ),
                      ),

                    SizedBox(height: 24),
                    Divider(),

                    SwitchListTile(
                      title: Text("Allow Members to Post"),
                      subtitle: Text("If off, only Admins/Editors can post."),
                      value: _allowMemberPosts,
                      onChanged: (widget.isOwner || widget.isAdmin) ? _updatePermission : null,
                      contentPadding: EdgeInsets.zero,
                    ),

                    Divider(),

                    if (widget.isOwner)
                      ListTile(
                        leading: Icon(Icons.delete_forever, color: Colors.red),
                        title: Text("Delete Community", style: TextStyle(color: Colors.red)),
                        subtitle: Text("Permanent action"),
                        onTap: _deleteCommunity,
                        contentPadding: EdgeInsets.zero,
                      )
                  ],
                ),

                // TAB 2: ROLES
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: "Search members...",
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16),
                        ),
                        onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                      ),
                    ),
                    Expanded(
                      child: _buildMemberList(ownerId),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberList(String ownerId) {
    // Filter the members based on search query
    final filteredMembers = _members.where((m) {
      final name = (m['name'] ?? '').toString().toLowerCase();
      final email = (m['email'] ?? '').toString().toLowerCase();
      return _searchQuery.isEmpty || name.contains(_searchQuery) || email.contains(_searchQuery);
    }).toList();

    if (filteredMembers.isEmpty) return Center(child: Text("No members found."));

    return ListView.builder(
      itemCount: filteredMembers.length,
      itemBuilder: (context, index) {
        final member = filteredMembers[index];
        final userId = member['uid'];
        final currentUid = FirebaseAuth.instance.currentUser?.uid;
        final isMe = userId == currentUid;

        final String name = member['name'] ?? 'Unknown';
        final String? avatarUrl = member['profile_image_url'];
        final String role = member['role'] ?? 'follower';

        String displayRole = "Member";
        Color displayColor = Colors.grey;

        if (userId == ownerId) {
          displayRole = "OWNER";
          displayColor = Colors.red;
        } else if (role == 'admin') {
          displayRole = "Admin";
          displayColor = Colors.blue;
        } else if (role == 'editor') {
          displayRole = "Editor";
          displayColor = Colors.green;
        } else if (role == 'moderator') {
          displayRole = "Moderator";
          displayColor = Colors.orange;
        }

        final bool canManageUser = widget.isOwner || (widget.isAdmin && userId != ownerId);

        return ListTile(
          leading: CircleAvatar(
            backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty ? CachedNetworkImageProvider(avatarUrl, cacheManager: AppCacheManager.instance) : null,
            child: avatarUrl == null || avatarUrl.isEmpty ? Icon(Icons.person) : null,
          ),
          title: Text(name),
          subtitle: Container(
            margin: EdgeInsets.only(top: 4),
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: displayColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: displayColor.withOpacity(0.5))
            ),
            child: Text(
              displayRole,
              style: TextStyle(color: displayColor, fontWeight: FontWeight.bold, fontSize: 10)
            ),
          ),

          trailing: (isMe || canManageUser) && userId != ownerId
            ? PopupMenuButton<String>(
                onSelected: (val) {
                  _updateRoleAccess(userId, val);
                },
                itemBuilder: (context) => [
                  if (canManageUser && !isMe) ...[
                    if (widget.isOwner) PopupMenuItem(value: 'make_admin', child: Text("Promote to Admin")),
                    PopupMenuItem(value: 'make_editor', child: Text("Set as Editor")),
                    PopupMenuItem(value: 'make_mod', child: Text("Set as Moderator")),
                    PopupMenuItem(value: 'remove_role', child: Text("Demote to Member")),
                    PopupMenuDivider(),
                    PopupMenuItem(value: 'kick', child: Text("Kick User", style: TextStyle(color: Colors.red))),
                  ]
                ],
              )
            : null,
        );
      },
    );
  }
}
