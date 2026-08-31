package imagestore

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"mime"
	"mime/multipart"
	"path/filepath"
	"strings"
	"time"

	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"
)

var allowedExtensions = map[string]bool{
	".jpg":  true,
	".jpeg": true,
	".png":  true,
	".webp": true,
	".heic": true,
	".gif":  true,
}

// ErrNotFound is returned by Open when the requested image doesn't exist.
var ErrNotFound = errors.New("image not found")

// ReadSeekCloser is what Open returns: a streamable object plus the ability
// to seek, which http.ServeContent needs to support HTTP Range requests.
type ReadSeekCloser interface {
	io.Reader
	io.Seeker
	io.Closer
}

// Store saves uploaded fish photos to an S3-compatible bucket (MinIO, or AWS
// S3 unmodified — the SDK speaks plain S3 API).
type Store struct {
	client *minio.Client
	bucket string
}

func New(endpoint, accessKey, secretKey, bucket string, useSSL bool) (*Store, error) {
	client, err := minio.New(endpoint, &minio.Options{
		Creds:  credentials.NewStaticV4(accessKey, secretKey, ""),
		Secure: useSSL,
	})
	if err != nil {
		return nil, fmt.Errorf("create minio client: %w", err)
	}

	ctx := context.Background()
	exists, err := client.BucketExists(ctx, bucket)
	if err != nil {
		return nil, fmt.Errorf("check bucket %q: %w", bucket, err)
	}
	if !exists {
		if err := client.MakeBucket(ctx, bucket, minio.MakeBucketOptions{}); err != nil {
			return nil, fmt.Errorf("create bucket %q: %w", bucket, err)
		}
	}

	return &Store{client: client, bucket: bucket}, nil
}

// Save uploads a file under a random object name and returns that name (not
// the full path/URL) for storage in the database.
func (s *Store) Save(fh *multipart.FileHeader) (string, error) {
	ext := strings.ToLower(filepath.Ext(fh.Filename))
	if !allowedExtensions[ext] {
		return "", fmt.Errorf("unsupported image type %q", ext)
	}

	src, err := fh.Open()
	if err != nil {
		return "", err
	}
	defer src.Close()

	name, err := randomFilename(ext)
	if err != nil {
		return "", err
	}

	contentType := mime.TypeByExtension(ext)
	if contentType == "" {
		contentType = "application/octet-stream"
	}

	_, err = s.client.PutObject(context.Background(), s.bucket, name, src, fh.Size, minio.PutObjectOptions{
		ContentType: contentType,
	})
	if err != nil {
		return "", err
	}

	return name, nil
}

// Delete removes a previously saved object by its name (as returned by
// Save). It rejects names containing path separators as a defense against
// path traversal.
func (s *Store) Delete(name string) error {
	if name != filepath.Base(name) {
		return fmt.Errorf("invalid image name %q", name)
	}
	return s.client.RemoveObject(context.Background(), s.bucket, name, minio.RemoveObjectOptions{})
}

// Open streams an object back for serving through the backend, along with
// its content type and last-modified time (used by http.ServeContent).
func (s *Store) Open(name string) (ReadSeekCloser, string, time.Time, error) {
	if name != filepath.Base(name) {
		return nil, "", time.Time{}, fmt.Errorf("invalid image name %q", name)
	}

	obj, err := s.client.GetObject(context.Background(), s.bucket, name, minio.GetObjectOptions{})
	if err != nil {
		return nil, "", time.Time{}, err
	}

	stat, err := obj.Stat()
	if err != nil {
		obj.Close()
		if minio.ToErrorResponse(err).Code == "NoSuchKey" {
			return nil, "", time.Time{}, ErrNotFound
		}
		return nil, "", time.Time{}, err
	}

	return obj, stat.ContentType, stat.LastModified, nil
}

func randomFilename(ext string) (string, error) {
	b := make([]byte, 16)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	return hex.EncodeToString(b) + ext, nil
}
