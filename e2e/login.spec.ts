import { test, expect } from '@playwright/test';

test.describe('Login Page', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    // Wait for the React app to fully hydrate
    await page.waitForLoadState('networkidle');
  });

  test('should display login form with all required fields', async ({ page }) => {
    // Verify the page title / logo area
    await expect(page.locator('text=Bienvenue Maram sur 4YOU')).toBeVisible({ timeout: 30000 });

    // Verify form fields are present
    await expect(page.locator('label:has-text("Votre identifiant")')).toBeVisible({ timeout: 10000 });
    await expect(page.locator('label:has-text("Votre mot de passe")')).toBeVisible({ timeout: 10000 });
    await expect(page.locator('label:has-text("Votre langue")')).toBeVisible({ timeout: 10000 });

    // Verify submit button
    await expect(page.locator('button[type="submit"]:has-text("Me connecter")')).toBeVisible({ timeout: 10000 });
  });

  test('should login successfully with valid credentials', async ({ page }) => {
    // Wait for form to be interactive
    await expect(page.locator('button[type="submit"]:has-text("Me connecter")')).toBeVisible({ timeout: 30000 });

    // Fill in valid credentials
    await page.locator('label:has-text("Votre identifiant")').locator('..').locator('input').fill('TNEEIN01');
    await page.locator('input[type="password"]').fill('4YOU');

    // Click submit
    await page.locator('button[type="submit"]:has-text("Me connecter")').click();

    // Should redirect to dashboard
    await expect(page).toHaveURL(/\/dashboard/, { timeout: 15000 });

    // Verify user info is displayed on dashboard
    await expect(page.locator('text=TNEEIN01')).toBeVisible({ timeout: 10000 });
  });

  test('should show error toast on invalid credentials', async ({ page }) => {
    // Wait for form to be interactive
    await expect(page.locator('button[type="submit"]:has-text("Me connecter")')).toBeVisible({ timeout: 30000 });

    // Fill in invalid credentials
    await page.locator('label:has-text("Votre identifiant")').locator('..').locator('input').fill('INVALID_USER');
    await page.locator('input[type="password"]').fill('wrong_password');

    // Click submit
    await page.locator('button[type="submit"]:has-text("Me connecter")').click();

    // Should stay on login page
    await expect(page).toHaveURL('/');

    // Should display error toast
    await expect(page.getByText('Erreur de connexion', { exact: true })).toBeVisible({ timeout: 5000 });
  });

  test('should not display dashboard content without auth', async ({ page }) => {
    // Try to navigate directly to dashboard
    await page.goto('/dashboard');
    await page.waitForLoadState('networkidle');

    // Wait for page to settle
    await page.waitForTimeout(2000);

    // The dashboard should NOT show any protected content (user info, etc.)
    const dashboardContent = page.locator('text=Mon solde de congés');
    await expect(dashboardContent).not.toBeVisible();
  });

  test('should logout successfully from dashboard', async ({ page }) => {
    // Wait for form to be interactive
    await expect(page.locator('button[type="submit"]:has-text("Me connecter")')).toBeVisible({ timeout: 30000 });

    // First login
    await page.locator('label:has-text("Votre identifiant")').locator('..').locator('input').fill('TNEEIN01');
    await page.locator('input[type="password"]').fill('4YOU');
    await page.locator('button[type="submit"]:has-text("Me connecter")').click();

    // Wait for dashboard
    await expect(page).toHaveURL(/\/dashboard/, { timeout: 15000 });

    // Click logout button (Power icon button)
    await page.locator('header button').last().click();

    // Should redirect back to login
    await expect(page).toHaveURL('/', { timeout: 10000 });
    await expect(page.locator('text=Bienvenue Maram sur 4YOU')).toBeVisible();
  });
});
