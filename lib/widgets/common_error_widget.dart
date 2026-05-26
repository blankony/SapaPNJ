import 'package:flutter/material.dart';
import '../main.dart';
import '../theme/app_theme.dart';
import '../theme/avatar_helper.dart';

class CommonErrorWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final bool isConnectionError;

  const CommonErrorWidget({
    super.key,
    this.message = "Something went wrong.",
    this.onRetry,
    this.isConnectionError = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isConnectionError ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
              size: 64,
              color: theme.hintColor.withOpacity(0.5),
            ),
            SizedBox(height: 16),
            Text(
              isConnectionError ? "No Connection" : "Oops!",
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.textTheme.bodyLarge?.color,
              ),
            ),
            SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.hintColor,
              ),
            ),
            if (onRetry != null) ...[
              SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: Icon(Icons.refresh),
                label: Text("Try Again"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: SisapaTheme.blue,
                  side: BorderSide(color: SisapaTheme.blue),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}