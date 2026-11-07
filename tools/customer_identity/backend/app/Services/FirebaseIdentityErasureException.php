<?php

declare(strict_types=1);

namespace App\Services;

/**
 * Sanitized exception for FirebaseIdentityErasure failures.
 *
 * Messages/codes are fixed and never contain UIDs, project IDs, or
 * upstream response bodies, so this is safe to surface in logs.
 */
final class FirebaseIdentityErasureException extends \RuntimeException
{
    public const INVALID_PROJECT = 1;
    public const INVALID_UID = 2;
    public const LOOKUP_MALFORMED = 3;
    public const LOOKUP_UNAVAILABLE = 4;
    public const FOREIGN_IDENTITY = 5;
    public const IDENTITY_CHANGED = 6;
    public const DELETE_UNAVAILABLE = 7;
    public const ERASURE_UNCONFIRMED = 8;
    public const INVALID_CREATED_AT = 9;

    private const MESSAGES = [
        self::INVALID_PROJECT => 'Invalid Firebase project configuration.',
        self::INVALID_UID => 'Invalid Firebase UID.',
        self::LOOKUP_MALFORMED => 'Firebase lookup response malformed.',
        self::LOOKUP_UNAVAILABLE => 'Firebase lookup unavailable.',
        self::FOREIGN_IDENTITY => 'Firebase lookup returned a non-matching identity.',
        self::IDENTITY_CHANGED => 'Identity generation mismatch; erasure aborted.',
        self::DELETE_UNAVAILABLE => 'Firebase delete unavailable.',
        self::ERASURE_UNCONFIRMED => 'Firebase erasure could not be confirmed.',
        self::INVALID_CREATED_AT => 'Invalid expected creation timestamp.',
    ];

    public function __construct(int $code)
    {
        parent::__construct(self::MESSAGES[$code] ?? 'Firebase identity erasure failed.', $code);
    }
}

