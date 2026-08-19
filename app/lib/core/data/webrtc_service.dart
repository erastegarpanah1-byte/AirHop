    // اصلاح درصد پیشرفت واقعی فرستنده بر اساس بایت‌های ارسال شده واقعی روی کارت شبکه (نه صرفاً بایت‌های کپی شده در رم)
    if (role == PeerRole.sender) {
      _channel!.onBufferedAmountChange =
          (int currentAmount, int changedAmount) {
        if (_currentFileTotalBytes > 0) {
          int actualSentOnNetwork = _currentFileSentToBuffer - currentAmount;
          if (actualSentOnNetwork < 0) actualSentOnNetwork = 0;
          if (actualSentOnNetwork > _currentFileTotalBytes) actualSentOnNetwork = _currentFileTotalBytes;

          _progress.add(TransferProgress(
            receivedBytes: actualSentOnNetwork,
            totalBytes: _currentFileTotalBytes,
          ));
        }
      };
    }
  }
