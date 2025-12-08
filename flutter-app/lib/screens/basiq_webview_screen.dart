import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:scan__pay/services/basiq_service.dart';
import 'package:scan__pay/theme.dart';

class BasiqWebViewScreen extends StatefulWidget {
  final String userId;
  final String payId;
  final String name;
  
  const BasiqWebViewScreen({
    super.key,
    required this.userId,
    required this.payId,
    required this.name,
  });
  
  @override
  State<BasiqWebViewScreen> createState() => _BasiqWebViewScreenState();
}

class _BasiqWebViewScreenState extends State<BasiqWebViewScreen> {
  WebViewController? _controller;
  bool _isLoading = true;
  bool _isLoadingUrl = true;
  String? _pageTitle;
  String? _connectUrl;
  String? _error;
  
  @override
  void initState() {
    super.initState();
    _loadConnectUrl();
  }
  
  Future<void> _loadConnectUrl() async {
    try {
      setState(() {
        _isLoadingUrl = true;
        _error = null;
      });
      
      // Get the connect URL from Cloud Function
      final result = await BasiqService.createConnectSession(
        userId: widget.userId,
        name: widget.name,
        payId: widget.payId,
      );
      
      if (result['success'] == true) {
        setState(() {
          _connectUrl = result['connectUrl'];
        });
        
        // Now initialize WebView with the real URL
        _initializeWebView();
      } else {
        setState(() {
          _error = result['message'] ?? 'Failed to create connect session';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error loading connect URL: $e';
      });
    } finally {
      setState(() {
        _isLoadingUrl = false;
      });
    }
  }
  
  void _initializeWebView() {
    // Initialize the WebView controller
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
            _updatePageTitle();
          },
          onNavigationRequest: (NavigationRequest request) {
            // Handle navigation redirects and completion
            if (request.url.contains('#success')) {
              _handleSuccess(request.url);
              return NavigationDecision.prevent;
            }
            if (request.url.contains('#cancel')) {
              _handleCancel();
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      );
    
    // Load the Basiq Connect URL
    _loadBasiqConnect();
  }
  
  void _loadBasiqConnect() {
    if (_controller == null) return;
    
    if (_connectUrl != null) {
      _controller!.loadRequest(Uri.parse(_connectUrl!));
    } else {
      // Fallback to demo page if no real URL available
      final demoUrl = _createDemoPage();
      _controller!.loadRequest(Uri.parse(demoUrl));
    }
  }
  
  
  String _createDemoPage() {
    // Create a simple demo HTML page that simulates Basiq Connect
    final demoHtml = '''
<!DOCTYPE html>
<html>
<head>
    <title>Basiq Connect Demo</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        body { font-family: Arial, sans-serif; padding: 20px; background: #f5f5f5; }
        .container { max-width: 400px; margin: 0 auto; background: white; border-radius: 12px; padding: 20px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #2c3e50; text-align: center; }
        .user-info { background: #ecf0f1; padding: 15px; border-radius: 8px; margin: 15px 0; }
        .user-info strong { color: #34495e; }
        .button { background: #3498db; color: white; border: none; padding: 12px 20px; border-radius: 6px; cursor: pointer; font-size: 16px; width: 100%; margin: 10px 0; }
        .button:hover { background: #2980b9; }
        .cancel { background: #95a5a6; }
        .cancel:hover { background: #7f8c8d; }
        .success { background: #27ae60; }
        .success:hover { background: #229954; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🏦 Connect to Bank</h1>
        <p>Connect your bank account to enable PayID seller functionality.</p>
        
        <div class="user-info">
            <div><strong>Name:</strong> ${widget.name}</div>
            <div><strong>PayID:</strong> ${widget.payId}</div>
            <div><strong>User ID:</strong> ${widget.userId}</div>
        </div>
        
        <p>This demo simulates connecting to your bank through Basiq's secure platform.</p>
        
        <button class="button success" onclick="connectSuccess()">✓ Connect Bank Account</button>
        
        <div id="status" style="margin-top: 20px; text-align: center;"></div>
    </div>
    
    <script>
        function connectSuccess() {
            document.getElementById('status').innerHTML = '<div style="color: #27ae60; font-weight: bold;">✓ Successfully connected!</div>';
            setTimeout(() => {
                window.location.href = 'about:blank#success?message=Bank account connected successfully';
            }, 1500);
        }
        
        function connectCancel() {
            window.location.href = 'about:blank#cancel?message=Connection cancelled by user';
        }
    </script>
</body>
</html>
    ''';
    
    // Convert to data URI
    final encodedHtml = Uri.dataFromString(demoHtml, mimeType: 'text/html').toString();
    return encodedHtml;
  }
  
  void _updatePageTitle() {
    _controller?.getTitle().then((title) {
      if (mounted) {
        setState(() {
          _pageTitle = title;
        });
      }
    });
  }
  
  void _handleSuccess(String url) {
    // Extract success parameters from URL if needed
    String message = 'Successfully connected to Basiq!';
    
    // Parse message from URL if present
    final uri = Uri.parse(url);
    final queryParams = uri.fragment.split('?').length > 1 
        ? Uri.splitQueryString(uri.fragment.split('?')[1])
        : <String, String>{};
    
    if (queryParams['message'] != null) {
      message = queryParams['message']!;
    }
    
    Navigator.of(context).pop({
      'success': true,
      'message': message,
    });
  }
  
  void _handleCancel() {
    Navigator.of(context).pop({
      'success': false,
      'message': 'Connection cancelled',
    });
  }
  
  void _goBack() {
    Navigator.of(context).pop({
      'success': false,
      'message': 'Connection cancelled',
    });
  }
  
  void _refresh() {
    _controller?.reload();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LightModeColors.lightSurface,
      appBar: AppBar(
        title: Text(
          _pageTitle ?? 'Connect to Basiq',
          style: TextStyle(color: LightModeColors.lightOnPrimaryContainer),
        ),
        backgroundColor: LightModeColors.lightAppBarBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.close,
            color: LightModeColors.lightOnPrimaryContainer,
          ),
          onPressed: _goBack,
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.refresh,
              color: LightModeColors.lightOnPrimaryContainer,
            ),
            onPressed: _refresh,
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_connectUrl != null && _controller != null) 
            WebViewWidget(controller: _controller!),
          if (_error != null)
            Container(
              color: LightModeColors.lightSurface,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: LightModeColors.errorRed,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _loadConnectUrl,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          if (_isLoadingUrl)
            Container(
              color: LightModeColors.lightSurface,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Creating Basiq Connect session...',
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            )
          else if (_isLoading && _connectUrl != null)
            Container(
              color: LightModeColors.lightSurface,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Loading Basiq Connect...',
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}