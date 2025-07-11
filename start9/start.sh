#!/bin/bash

set -euo pipefail

# Start9 specific initialization
export UPLOAD_LOCATION="/data/library"
export DB_DATA_LOCATION="/data/postgres"
export DB_USERNAME="postgres"
export DB_DATABASE_NAME="immich"
export DB_PASSWORD="immich_password_$(openssl rand -hex 16)"
export IMMICH_VERSION="release"
export TZ="UTC"

# Create necessary directories
mkdir -p "$UPLOAD_LOCATION"
mkdir -p "$DB_DATA_LOCATION"
mkdir -p /data/config
mkdir -p /data/redis

# Generate configuration files
cat > /data/config/immich.json <<EOF
{
  "ffmpeg": {
    "crf": 23,
    "threads": 0,
    "preset": "ultrafast",
    "targetVideoCodec": "h264",
    "acceptedVideoCodecs": ["h264"],
    "targetAudioCodec": "aac",
    "acceptedAudioCodecs": ["aac", "mp3", "libmp3lame"],
    "targetResolution": "720",
    "maxBitrate": "0",
    "bframes": -1,
    "refs": 0,
    "gopSize": 0,
    "npl": 0,
    "temporalAQ": false,
    "cqMode": "auto",
    "twoPass": false,
    "preferredHwDevice": "auto",
    "transcode": "required",
    "tonemap": "hable",
    "accel": "disabled"
  },
  "job": {
    "backgroundTask": {
      "concurrency": 5
    },
    "smartSearch": {
      "concurrency": 2
    },
    "metadataExtraction": {
      "concurrency": 5
    },
    "faceDetection": {
      "concurrency": 2
    },
    "search": {
      "concurrency": 5
    },
    "sidecar": {
      "concurrency": 5
    },
    "library": {
      "concurrency": 5
    },
    "migration": {
      "concurrency": 5
    },
    "thumbnailGeneration": {
      "concurrency": 5
    },
    "videoConversion": {
      "concurrency": 1
    }
  },
  "logging": {
    "enabled": true,
    "level": "log"
  },
  "machineLearning": {
    "enabled": true,
    "url": "http://localhost:3003",
    "clip": {
      "enabled": true,
      "modelName": "ViT-B-32__openai"
    },
    "duplicateDetection": {
      "enabled": true,
      "maxDistance": 0.01
    },
    "facialRecognition": {
      "enabled": true,
      "modelName": "buffalo_l",
      "minScore": 0.7,
      "maxDistance": 0.5,
      "minFaces": 3
    }
  },
  "map": {
    "enabled": true,
    "lightStyle": "",
    "darkStyle": ""
  },
  "reverseGeocoding": {
    "enabled": true
  },
  "oauth": {
    "enabled": false,
    "issuerUrl": "",
    "clientId": "",
    "clientSecret": "",
    "scope": "openid email profile",
    "signingAlgorithm": "RS256",
    "storageLabelClaim": "preferred_username",
    "storageQuotaClaim": "immich_quota",
    "defaultStorageQuota": 0,
    "buttonText": "Login with OAuth",
    "autoRegister": true,
    "autoLaunch": false,
    "mobileOverrideEnabled": false,
    "mobileRedirectUri": ""
  },
  "passwordLogin": {
    "enabled": true
  },
  "storageTemplate": {
    "enabled": false,
    "hashVerificationEnabled": true,
    "template": "{{y}}/{{y}}-{{MM}}-{{dd}}/{{filename}}"
  },
  "image": {
    "thumbnail": {
      "format": "webp",
      "size": 250,
      "quality": 80
    },
    "preview": {
      "format": "jpeg",
      "size": 1440,
      "quality": 80
    }
  },
  "newVersionCheck": {
    "enabled": true
  },
  "trash": {
    "enabled": true,
    "days": 30
  },
  "theme": {
    "customCss": ""
  },
  "library": {
    "scan": {
      "enabled": true,
      "cronExpression": "0 0 * * *"
    },
    "watch": {
      "enabled": false
    }
  },
  "server": {
    "externalDomain": "",
    "loginPageMessage": ""
  },
  "notifications": {
    "smtp": {
      "enabled": false,
      "from": "",
      "replyTo": "",
      "transport": {
        "host": "",
        "port": 587,
        "username": "",
        "password": "",
        "ignoreCert": false
      }
    }
  },
  "user": {
    "deleteDelay": 7
  }
}
EOF

# Write the properties file for Start9
cat > /data/config/properties.yaml <<EOF
url: "https://$(hostname).local"
username: "admin"
EOF

# Set permissions
chown -R 1001:1001 /data

# Export environment variables for the main immich process
export IMMICH_CONFIG_FILE="/data/config/immich.json"

# Start the main Immich server
exec /usr/src/app/start.sh immich