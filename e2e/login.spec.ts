import { test, expect } from '@playwright/test';

test.describe('Login Page', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
  });

  test('should display login form with all required fields', async ({ page }) => {
    // Verify the page title / logo area

    await expect(page.locator('text=Bienvenue Maram sur 4YOU')).toBeVisible();

    // Verify form fields are present
    await expect(page.locator('label:has-text("Votre identifiant")')).toBeVisible();
    await expect(page.locator('label:has-text("Votre mot de passe")')).toBeVisible();
    await expect(page.locator('label:has-text("Votre langue")')).toBeVisible();

    // Verify submit button
    await expect(page.locator('button[type="submit"]:has-text("Me connecter")')).toBeVisible();
  });

  test('should login successfully with valid credentials', async ({ page }) => {
    // Fill in valid credentials
    const identifierInput = page.locator('label:has-text("Votre identifiant") + input, label:has-text("Votre identifiant") ~ input').first();
    const passwordInput = page.locator('input[type="password"]');

    // Use the parent div structure to find inputs
    await page.locator('label:has-text("Votre identifiant")').locator('..').locator('input').fill('TNEEIN01');
    await passwordInput.fill('4YOU');

    // Click submit
    await page.locator('button[type="submit"]:has-text("Me connecter")').click();

    // Should redirect to dashboard
    await expect(page).toHaveURL(/\/dashboard/);

    // Verify user info is displayed on dashboard
    await expect(page.locator('text=TNEEIN01')).toBeVisible();
  });

  test('should show error toast on invalid credentials', async ({ page }) => {
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

    // Wait for page to settle
    await page.waitForTimeout(2000);

    // The dashboard should NOT show any protected content (user info, etc.)
    // Either it redirects to login or shows nothing
    const dashboardContent = page.locator('text=Mon solde de congés');
    await expect(dashboardContent).not.toBeVisible();
  });

  test('should logout successfully from dashboard', async ({ page }) => {
    // First login
    await page.locator('label:has-text("Votre identifiant")').locator('..').locator('input').fill('TNEEIN01');
    await page.locator('input[type="password"]').fill('4YOU');
    await page.locator('button[type="submit"]:has-text("Me connecter")').click();

    // Wait for dashboard
    await expect(page).toHaveURL(/\/dashboard/);

    // Click logout button (Power icon button)
    await page.locator('header button').last().click();

    // Should redirect back to login
    await expect(page).toHaveURL('/');
    await expect(page.locator('text=Bienvenue Maram sur 4YOU')).toBeVisible();
  });
});

