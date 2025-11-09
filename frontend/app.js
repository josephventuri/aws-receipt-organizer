// API Configuration
const API_ENDPOINT = 'https://z3ble2cysi.execute-api.us-west-1.amazonaws.com/prod/upload-url';

// DOM Elements
const camera = document.getElementById('camera');
const canvas = document.getElementById('canvas');
const preview = document.getElementById('preview');
const previewImage = document.getElementById('previewImage');
const captureBtn = document.getElementById('captureBtn');
const retakeBtn = document.getElementById('retakeBtn');
const uploadBtn = document.getElementById('uploadBtn');
const statusDiv = document.getElementById('status');
const progressDiv = document.getElementById('progress');
const progressBar = document.getElementById('progressBar');

let stream = null;
let capturedImageBlob = null;

// Initialize Camera
async function initCamera() {
    try {
        stream = await navigator.mediaDevices.getUserMedia({
            video: {
                facingMode: 'environment', // Use back camera on mobile
                width: { ideal: 1920 },
                height: { ideal: 1080 }
            }
        });
        camera.srcObject = stream;
        showStatus('Camera ready', 'info');
    } catch (error) {
        console.error('Camera error:', error);
        showStatus('Unable to access camera. Please check permissions.', 'error');
    }
}

// Capture Photo
function capturePhoto() {
    // Set canvas dimensions to match video
    canvas.width = camera.videoWidth;
    canvas.height = camera.videoHeight;

    // Draw current frame to canvas
    const context = canvas.getContext('2d');
    context.drawImage(camera, 0, 0, canvas.width, canvas.height);

    // Convert to blob
    canvas.toBlob((blob) => {
        capturedImageBlob = blob;
        previewImage.src = URL.createObjectURL(blob);

        // Hide camera, show preview
        camera.style.display = 'none';
        preview.style.display = 'block';

        // Update buttons
        captureBtn.style.display = 'none';
        retakeBtn.style.display = 'block';
        uploadBtn.style.display = 'block';

        showStatus('Photo captured! Ready to upload.', 'success');
    }, 'image/jpeg', 0.9);
}

// Retake Photo
function retakePhoto() {
    // Show camera, hide preview
    camera.style.display = 'block';
    preview.style.display = 'none';

    // Update buttons
    captureBtn.style.display = 'block';
    retakeBtn.style.display = 'none';
    uploadBtn.style.display = 'none';

    // Clear captured image
    capturedImageBlob = null;
    showStatus('Camera ready', 'info');
}

// Upload Receipt
async function uploadReceipt() {
    if (!capturedImageBlob) {
        const msg = 'No photo to upload';
        showStatus(msg, 'error');
        alert(msg);
        return;
    }

    try {
        uploadBtn.disabled = true;
        retakeBtn.disabled = true;
        showStatus('Getting upload URL...', 'info');
        progressDiv.style.display = 'block';
        updateProgress(25);

        console.log('Requesting presigned URL from:', API_ENDPOINT);

        // Get pre-signed URL from API
        const response = await fetch(API_ENDPOINT, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                fileType: 'image/jpeg'
            })
        });

        console.log('API Response status:', response.status);

        if (!response.ok) {
            const errorText = await response.text();
            console.error('API Error response:', errorText);
            throw new Error(`Failed to get upload URL (${response.status}): ${errorText}`);
        }

        const data = await response.json();
        console.log('Received presigned URL data:', data);
        updateProgress(50);

        showStatus('Uploading receipt...', 'info');

        // Upload to S3 using pre-signed URL
        console.log('Uploading to S3...');
        const uploadResponse = await fetch(data.uploadUrl, {
            method: 'PUT',
            headers: {
                'Content-Type': 'image/jpeg'
            },
            body: capturedImageBlob
        });

        console.log('S3 Upload response status:', uploadResponse.status);

        if (!uploadResponse.ok) {
            const errorText = await uploadResponse.text();
            console.error('S3 Upload error:', errorText);
            throw new Error(`Failed to upload receipt (${uploadResponse.status}): ${errorText}`);
        }

        updateProgress(100);
        showStatus('Receipt uploaded successfully! Processing and email on the way.', 'success');
        console.log('Upload completed successfully!');

        // Show success alert
        alert('Receipt uploaded successfully! Check your email for details.');

        // Reset after 3 seconds
        setTimeout(() => {
            retakePhoto();
            progressDiv.style.display = 'none';
            updateProgress(0);
            uploadBtn.disabled = false;
            retakeBtn.disabled = false;
        }, 3000);

    } catch (error) {
        console.error('Upload error:', error);
        const errorMsg = `Upload failed: ${error.message}`;
        showStatus(errorMsg, 'error');

        // Show alert so user definitely sees the error
        alert(errorMsg);

        uploadBtn.disabled = false;
        retakeBtn.disabled = false;
        progressDiv.style.display = 'none';
        updateProgress(0);
    }
}

// Show Status Message
function showStatus(message, type) {
    statusDiv.textContent = message;
    statusDiv.className = `status ${type}`;
}

// Update Progress Bar
function updateProgress(percent) {
    progressBar.style.width = `${percent}%`;
}

// Event Listeners
captureBtn.addEventListener('click', capturePhoto);
retakeBtn.addEventListener('click', retakePhoto);
uploadBtn.addEventListener('click', uploadReceipt);

// Global error handler
window.addEventListener('error', (event) => {
    console.error('Global error:', event.error);
    alert(`JavaScript Error: ${event.error?.message || 'Unknown error'}`);
});

window.addEventListener('unhandledrejection', (event) => {
    console.error('Unhandled promise rejection:', event.reason);
    alert(`Promise Error: ${event.reason?.message || event.reason}`);
});

// Initialize app
initCamera();

// PWA Install Prompt
let deferredPrompt;

window.addEventListener('beforeinstallprompt', (e) => {
    e.preventDefault();
    deferredPrompt = e;
    // Could show custom install button here
});

// Register Service Worker
if ('serviceWorker' in navigator) {
    navigator.serviceWorker.register('service-worker.js')
        .then(registration => console.log('Service Worker registered'))
        .catch(error => console.log('Service Worker registration failed:', error));
}
