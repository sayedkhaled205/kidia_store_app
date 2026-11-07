<?php
use App\Http\Controllers\Api\V1\StoreCustomerIdentityController;
use App\Http\Middleware\AuthenticateStoreNotifications;
use Illuminate\Support\Facades\Route;

Route::prefix('v1/stores/{store}/customer-identities')
    ->middleware([AuthenticateStoreNotifications::class, 'throttle:30,1'])
    ->group(function (): void {
        Route::get('/capabilities', [StoreCustomerIdentityController::class, 'capabilities']);
        Route::post('/lookup', [StoreCustomerIdentityController::class, 'lookup']);
        Route::post('/erase', [StoreCustomerIdentityController::class, 'erase']);
    });
