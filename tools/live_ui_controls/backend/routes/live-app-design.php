<?php
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Portal\LiveAppDesignController;

Route::get('/v1/app-design/{store}', [LiveAppDesignController::class, 'show'])->whereUuid('store')->name('live-design.public');
Route::middleware(['auth', 'throttle:30,1'])->prefix('account/builder/live-design')->group(function (): void {
    Route::get('/', [LiveAppDesignController::class, 'status']);
    Route::get('/controls', [LiveAppDesignController::class, 'controls']);
    Route::post('/controls', [LiveAppDesignController::class, 'saveControls']);
    Route::post('/publish', [LiveAppDesignController::class, 'publish']);
    Route::post('/rollback', [LiveAppDesignController::class, 'rollback']);
});
