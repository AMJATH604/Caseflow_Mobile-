import { test, expect } from '@playwright/test';

test.describe('Dashboard Smoke Tests', () => {
    test('should load the authentication page', async ({ page }) => {
        await page.goto('/');

        // Check for "AI Advocate Dashboard" title
        await expect(page.locator('text=AI Advocate Dashboard')).toBeVisible();

        // Check for Email and Password fields
        await expect(page.locator('#email')).toBeVisible();
        await expect(page.locator('#password')).toBeVisible();

        // Check for "Sign In" button
        await expect(page.locator('button:has-text("Sign In")')).toBeVisible();
    });

    test('should toggle between Sign In and Sign Up', async ({ page }) => {
        await page.goto('/');

        // Initial state: Sign In
        await expect(page.locator('text=Sign in to your account')).toBeVisible();

        // Click "Don't have an account? Sign up"
        await page.click('button:has-text("Don\'t have an account? Sign up")');

        // State: Sign Up
        await expect(page.locator('text=Create your advocate account')).toBeVisible();
        await expect(page.locator('#name')).toBeVisible();

        // Click back to Sign In
        await page.click('button:has-text("Already have an account? Sign in")');
        await expect(page.locator('text=Sign in to your account')).toBeVisible();
    });
});
