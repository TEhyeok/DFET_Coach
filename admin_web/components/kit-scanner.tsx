'use client';

import { useEffect, useRef, useState } from 'react';

declare class BarcodeDetector {
  constructor(options: { formats: string[] });
  detect(source: ImageBitmapSource): Promise<Array<{ rawValue: string }>>;
}

export function KitScanner({ onValue }: { onValue: (value: string) => void }) {
  const video = useRef<HTMLVideoElement>(null);
  const [active, setActive] = useState(false);
  const [message, setMessage] = useState('');

  useEffect(() => {
    if (!active) return;
    let stream: MediaStream | undefined;
    let cancelled = false;
    let timer = 0;
    async function start() {
      if (typeof BarcodeDetector === 'undefined') {
        setMessage('이 브라우저는 QR/바코드 스캔을 지원하지 않습니다. 직접 입력해 주세요.');
        setActive(false);
        return;
      }
      stream = await navigator.mediaDevices.getUserMedia({
        video: { facingMode: 'environment' },
        audio: false,
      });
      if (!video.current) return;
      video.current.srcObject = stream;
      await video.current.play();
      const detector = new BarcodeDetector({ formats: ['qr_code', 'data_matrix'] });
      const scan = async () => {
        if (cancelled || !video.current) return;
        const results = await detector.detect(video.current).catch(() => []);
        if (results[0]?.rawValue) {
          onValue(results[0].rawValue);
          setActive(false);
          return;
        }
        timer = window.setTimeout(scan, 350);
      };
      await scan();
    }
    start().catch((cause) => {
      setMessage(cause instanceof Error ? cause.message : '카메라를 열 수 없습니다.');
      setActive(false);
    });
    return () => {
      cancelled = true;
      window.clearTimeout(timer);
      stream?.getTracks().forEach((track) => track.stop());
    };
  }, [active, onValue]);

  return (
    <div>
      <button className="button secondary" onClick={() => setActive((value) => !value)} type="button">
        {active ? '스캔 중지' : 'QR/UDI 스캔'}
      </button>
      {active ? <video ref={video} muted playsInline style={{ width: '100%', marginTop: 10, borderRadius: 12 }} /> : null}
      {message ? <div className="error">{message}</div> : null}
    </div>
  );
}
