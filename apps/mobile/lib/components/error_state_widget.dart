import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../theme/app_theme.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ErrorStateWidget extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  final String? message;

  ErrorStateWidget({
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
            padding: EdgeInsets.all(32.0.r),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildIcon(isOffline),
                SizedBox(height: 24.h),
                Text(
                  isOffline ? 'No Internet Connection' : 'Something went wrong',
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                ),
                SizedBox(height: 12.h),
                Text(
                  isOffline
                      ? 'Please check your network settings and try again.'
                      : (message ?? error.toString()),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600], fontSize: 14.sp),
                ),
                SizedBox(height: 32.h),
                SizedBox(
                  width: 200.w,
                  height: 48.h,
                  child: ElevatedButton(
                    onPressed: onRetry,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.refresh_rounded, size: 18),
                        SizedBox(width: 8.w),
                        Text(
                          'Try Again',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                if (isOffline) ...[
                  SizedBox(height: 16.h),
                  TextButton(
                    onPressed: () {
                      // Optional: Open system settings or show more details
                    },
                    child: Text(
                      'Network Troubleshooting',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12.sp),
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
      padding: EdgeInsets.all(24.r),
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
