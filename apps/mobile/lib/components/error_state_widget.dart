import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../theme/app_theme.dart';

class ErrorStateWidget extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  final String? message;

  const ErrorStateWidget({
    super.key,
    required this.error,
    required this.onRetry,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ConnectivityResult>>(
      future: Connectivity().checkConnectivity(),
      builder: (context, snapshot) {
        final isOffline =
            snapshot.hasData &&
            snapshot.data!.any((result) => result == ConnectivityResult.none);

        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildIcon(isOffline),
                const SizedBox(height: 24),
                Text(
                  isOffline ? "No Internet Connection" : "Something went wrong",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  isOffline
                      ? "Please check your network settings and try again."
                      : (message ?? error.toString()),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: 200,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: onRetry,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.refresh_rounded, size: 18),
                        SizedBox(width: 8),
                        Text(
                          "Try Again",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                if (isOffline) ...[
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      // Optional: Open system settings or show more details
                    },
                    child: Text(
                      "Network Troubleshooting",
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildIcon(bool isOffline) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: (isOffline ? Colors.orange : AppTheme.error).withValues(
          alpha: 0.1,
        ),
        shape: BoxShape.circle,
      ),
      child: Icon(
        isOffline ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
        size: 48,
        color: isOffline ? Colors.orange : AppTheme.error,
      ),
    );
  }
}
