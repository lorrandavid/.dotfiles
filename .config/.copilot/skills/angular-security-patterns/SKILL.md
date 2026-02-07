---
name: angular-security-patterns
description: Use when building secure Angular applications with robust authentication and authorization mechanisms.
---

# Authentication & Authorization Patterns

Complete guide to secure authentication and authorization in Angular applications.

## Table of Contents

1. [Authentication Basics](#authentication-basics)
2. [JWT Implementation](#jwt-implementation)
3. [OAuth2 & Social Login](#oauth2--social-login)
4. [Token Management](#token-management)
5. [Route Guards](#route-guards)
6. [Role-Based Access Control](#role-based-access-control)
7. [HTTP Interceptors](#http-interceptors)
8. [Session Management](#session-management)

---

## Authentication Basics

### Authentication Flow

```
1. User enters credentials
2. Frontend sends to backend
3. Backend validates credentials
4. Backend generates JWT token
5. Frontend stores token securely
6. Frontend includes token in API requests
7. Backend validates token on each request
```

### Secure Authentication Service

```typescript
@Injectable({ providedIn: 'root' })
export class AuthService {
  private readonly TOKEN_KEY = 'auth_token';
  private currentUserSubject = new BehaviorSubject<User | null>(null);
  public currentUser$ = this.currentUserSubject.asObservable();
  
  constructor(
    private http: HttpClient,
    private router: Router
  ) {
    // Initialize user from token on app start
    this.loadUserFromToken();
  }
  
  login(email: string, password: string): Observable<AuthResponse> {
    return this.http.post<AuthResponse>('/api/auth/login', {
      email,
      password
    }).pipe(
      tap(response => {
        this.setSession(response);
      }),
      catchError(error => {
        console.error('Login failed:', error);
        return throwError(() => error);
      })
    );
  }
  
  logout(): void {
    // Clear token
    localStorage.removeItem(this.TOKEN_KEY);
    
    // Clear user state
    this.currentUserSubject.next(null);
    
    // Redirect to login
    this.router.navigate(['/login']);
    
    // Optional: Call backend to invalidate token
    this.http.post('/api/auth/logout', {}).subscribe();
  }
  
  isAuthenticated(): boolean {
    const token = this.getToken();
    if (!token) return false;
    
    // Check if token is expired
    return !this.isTokenExpired(token);
  }
  
  getToken(): string | null {
    return localStorage.getItem(this.TOKEN_KEY);
  }
  
  private setSession(authResult: AuthResponse): void {
    // Store token
    localStorage.setItem(this.TOKEN_KEY, authResult.token);
    
    // Update current user
    this.currentUserSubject.next(authResult.user);
  }
  
  private loadUserFromToken(): void {
    const token = this.getToken();
    if (token && !this.isTokenExpired(token)) {
      // Decode token to get user info
      const decoded = this.decodeToken(token);
      this.currentUserSubject.next(decoded.user);
    }
  }
  
  private isTokenExpired(token: string): boolean {
    try {
      const decoded = this.decodeToken(token);
      const expiryTime = decoded.exp * 1000; // Convert to milliseconds
      return Date.now() >= expiryTime;
    } catch {
      return true;
    }
  }
  
  private decodeToken(token: string): any {
    try {
      const payload = token.split('.')[1];
      return JSON.parse(atob(payload));
    } catch {
      return null;
    }
  }
}
```

---

## JWT Implementation

### JWT Structure

```
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.  // Header
eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.  // Payload
SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c  // Signature
```

### JWT Payload

```typescript
interface JwtPayload {
  sub: string;        // Subject (user ID)
  email: string;      // User email
  name: string;       // User name
  role: string;       // User role
  iat: number;        // Issued at
  exp: number;        // Expiration time
}
```

### JWT Service

```typescript
@Injectable({ providedIn: 'root' })
export class JwtService {
  private readonly SECRET_KEY = 'your-secret-key'; // Server-side only!
  
  // Decode JWT (client-side)
  decode(token: string): any {
    try {
      const parts = token.split('.');
      if (parts.length !== 3) {
        throw new Error('Invalid token format');
      }
      
      const payload = parts[1];
      const decoded = atob(payload.replace(/-/g, '+').replace(/_/g, '/'));
      return JSON.parse(decoded);
    } catch (error) {
      console.error('Failed to decode token:', error);
      return null;
    }
  }
  
  // Check if token is expired
  isExpired(token: string): boolean {
    const decoded = this.decode(token);
    if (!decoded || !decoded.exp) return true;
    
    const expiryTime = decoded.exp * 1000;
    return Date.now() >= expiryTime;
  }
  
  // Get expiry date
  getExpiryDate(token: string): Date | null {
    const decoded = this.decode(token);
    if (!decoded || !decoded.exp) return null;
    
    return new Date(decoded.exp * 1000);
  }
  
  // Get time until expiry
  getTimeUntilExpiry(token: string): number {
    const expiryDate = this.getExpiryDate(token);
    if (!expiryDate) return 0;
    
    return expiryDate.getTime() - Date.now();
  }
}
```

### Token Refresh

```typescript
@Injectable({ providedIn: 'root' })
export class TokenRefreshService {
  private refreshInProgress = false;
  private refreshSubject = new Subject<string>();
  
  constructor(
    private http: HttpClient,
    private authService: AuthService
  ) {
    // Auto-refresh before expiry
    this.setupAutoRefresh();
  }
  
  refreshToken(): Observable<string> {
    if (this.refreshInProgress) {
      // Return existing refresh observable
      return this.refreshSubject.pipe(
        filter(token => !!token),
        take(1)
      );
    }
    
    this.refreshInProgress = true;
    
    return this.http.post<{ token: string }>('/api/auth/refresh', {
      refreshToken: this.authService.getRefreshToken()
    }).pipe(
      tap(response => {
        this.authService.setToken(response.token);
        this.refreshInProgress = false;
        this.refreshSubject.next(response.token);
      }),
      catchError(error => {
        this.refreshInProgress = false;
        this.authService.logout();
        return throwError(() => error);
      })
    );
  }
  
  private setupAutoRefresh(): void {
    // Refresh token 5 minutes before expiry
    const REFRESH_BEFORE_EXPIRY = 5 * 60 * 1000; // 5 minutes
    
    interval(60000).pipe( // Check every minute
      filter(() => this.authService.isAuthenticated()),
      switchMap(() => {
        const token = this.authService.getToken();
        if (!token) return of(null);
        
        const timeUntilExpiry = this.getTimeUntilExpiry(token);
        
        if (timeUntilExpiry <= REFRESH_BEFORE_EXPIRY) {
          return this.refreshToken();
        }
        return of(null);
      })
    ).subscribe();
  }
  
  private getTimeUntilExpiry(token: string): number {
    const decoded = this.decodeToken(token);
    if (!decoded?.exp) return 0;
    return (decoded.exp * 1000) - Date.now();
  }
}
```

---

## OAuth2 & Social Login

### OAuth2 Flow

```
1. User clicks "Login with Google"
2. Redirect to OAuth provider (Google)
3. User authorizes app
4. Provider redirects back with authorization code
5. Exchange code for access token
6. Use token to get user info
7. Create session in your app
```

### Social Login Service

```typescript
@Injectable({ providedIn: 'root' })
export class SocialAuthService {
  constructor(
    private http: HttpClient,
    private authService: AuthService
  ) {}
  
  // Google OAuth2
  loginWithGoogle(): void {
    const clientId = environment.googleClientId;
    const redirectUri = `${window.location.origin}/auth/google/callback`;
    const scope = 'openid email profile';
    
    const authUrl = `https://accounts.google.com/o/oauth2/v2/auth?` +
      `client_id=${clientId}&` +
      `redirect_uri=${encodeURIComponent(redirectUri)}&` +
      `response_type=code&` +
      `scope=${encodeURIComponent(scope)}`;
    
    window.location.href = authUrl;
  }
  
  // Handle OAuth callback
  handleOAuthCallback(code: string, provider: string): Observable<AuthResponse> {
    return this.http.post<AuthResponse>('/api/auth/oauth/callback', {
      code,
      provider
    }).pipe(
      tap(response => {
        this.authService.setSession(response);
      })
    );
  }
  
  // GitHub OAuth2
  loginWithGitHub(): void {
    const clientId = environment.githubClientId;
    const redirectUri = `${window.location.origin}/auth/github/callback`;
    
    const authUrl = `https://github.com/login/oauth/authorize?` +
      `client_id=${clientId}&` +
      `redirect_uri=${encodeURIComponent(redirectUri)}&` +
      `scope=user:email`;
    
    window.location.href = authUrl;
  }
}
```

### OAuth Callback Component

```typescript
@Component({
  template: `<div>Completing login...</div>`
})
export class OAuthCallbackComponent implements OnInit {
  constructor(
    private route: ActivatedRoute,
    private socialAuth: SocialAuthService,
    private router: Router
  ) {}
  
  ngOnInit() {
    // Get authorization code from URL
    this.route.queryParams.subscribe(params => {
      const code = params['code'];
      const provider = this.route.snapshot.paramMap.get('provider');
      
      if (code && provider) {
        this.socialAuth.handleOAuthCallback(code, provider).subscribe({
          next: () => {
            this.router.navigate(['/dashboard']);
          },
          error: (error) => {
            console.error('OAuth callback failed:', error);
            this.router.navigate(['/login'], {
              queryParams: { error: 'oauth_failed' }
            });
          }
        });
      }
    });
  }
}
```

---

## Token Management

### Secure Token Storage

```typescript
@Injectable({ providedIn: 'root' })
export class SecureTokenService {
  // Option 1: Memory (most secure, lost on refresh)
  private token: string | null = null;
  
  setToken(token: string): void {
    this.token = token;
  }
  
  getToken(): string | null {
    return this.token;
  }
  
  clearToken(): void {
    this.token = null;
  }
}

// Option 2: localStorage (survives refresh, vulnerable to XSS)
class LocalStorageTokenService {
  private readonly KEY = 'auth_token';
  
  setToken(token: string): void {
    localStorage.setItem(this.KEY, token);
  }
  
  getToken(): string | null {
    return localStorage.getItem(this.KEY);
  }
  
  clearToken(): void {
    localStorage.removeItem(this.KEY);
  }
}

// Option 3: HttpOnly cookie (most secure, set server-side)
// Backend sets: Set-Cookie: token=xxx; HttpOnly; Secure; SameSite=Strict
// Frontend: Token automatically sent with requests
```

### Token Encryption (Client-Side)

```typescript
@Injectable({ providedIn: 'root' })
export class EncryptedTokenService {
  private readonly KEY = 'auth_token';
  private readonly ENCRYPTION_KEY = 'your-encryption-key'; // From environment
  
  setToken(token: string): void {
    const encrypted = this.encrypt(token);
    localStorage.setItem(this.KEY, encrypted);
  }
  
  getToken(): string | null {
    const encrypted = localStorage.getItem(this.KEY);
    if (!encrypted) return null;
    
    return this.decrypt(encrypted);
  }
  
  private encrypt(text: string): string {
    // Use Web Crypto API
    // This is a simplified example
    return btoa(text); // In production, use proper encryption
  }
  
  private decrypt(encrypted: string): string {
    try {
      return atob(encrypted);
    } catch {
      return '';
    }
  }
}
```

---

## Route Guards

### Auth Guard

```typescript
export const authGuard: CanActivateFn = (route, state) => {
  const authService = inject(AuthService);
  const router = inject(Router);
  
  if (authService.isAuthenticated()) {
    return true;
  }
  
  // Redirect to login with return URL
  return router.createUrlTree(['/login'], {
    queryParams: { returnUrl: state.url }
  });
};

// Usage in routes
export const routes: Routes = [
  {
    path: 'dashboard',
    canActivate: [authGuard],
    loadComponent: () => import('./dashboard/dashboard.component')
  }
];
```

### Role Guard

```typescript
export const roleGuard: CanActivateFn = (route, state) => {
  const authService = inject(AuthService);
  const router = inject(Router);
  
  // Check authentication
  if (!authService.isAuthenticated()) {
    return router.createUrlTree(['/login']);
  }
  
  // Check role
  const requiredRole = route.data['role'] as string;
  const userRole = authService.getCurrentUser()?.role;
  
  if (requiredRole && userRole !== requiredRole) {
    console.warn(`Access denied. Required role: ${requiredRole}, User role: ${userRole}`);
    return router.createUrlTree(['/unauthorized']);
  }
  
  return true;
};

// Usage
{
  path: 'admin',
  canActivate: [authGuard, roleGuard],
  data: { role: 'admin' },
  loadChildren: () => import('./admin/admin.routes')
}
```

### Permission Guard

```typescript
export const permissionGuard: CanActivateFn = (route, state) => {
  const authService = inject(AuthService);
  const router = inject(Router);
  
  if (!authService.isAuthenticated()) {
    return router.createUrlTree(['/login']);
  }
  
  const requiredPermissions = route.data['permissions'] as string[];
  const userPermissions = authService.getCurrentUser()?.permissions || [];
  
  const hasPermission = requiredPermissions.every(permission =>
    userPermissions.includes(permission)
  );
  
  if (!hasPermission) {
    return router.createUrlTree(['/forbidden']);
  }
  
  return true;
};

// Usage
{
  path: 'users/edit/:id',
  canActivate: [authGuard, permissionGuard],
  data: { permissions: ['users.edit', 'users.view'] },
  component: UserEditComponent
}
```

### Can Deactivate Guard

```typescript
export interface CanComponentDeactivate {
  canDeactivate: () => boolean | Observable<boolean>;
}

export const unsavedChangesGuard: CanDeactivateFn<CanComponentDeactivate> = (
  component
) => {
  return component.canDeactivate
    ? component.canDeactivate()
    : true;
};

// Component implementation
@Component({})
export class EditFormComponent implements CanComponentDeactivate {
  hasUnsavedChanges = false;
  
  canDeactivate(): boolean {
    if (this.hasUnsavedChanges) {
      return confirm('You have unsaved changes. Are you sure you want to leave?');
    }
    return true;
  }
}

// Route
{
  path: 'edit/:id',
  component: EditFormComponent,
  canDeactivate: [unsavedChangesGuard]
}
```

---

## Role-Based Access Control

### RBAC Service

```typescript
interface Permission {
  resource: string;
  actions: string[];
}

interface Role {
  name: string;
  permissions: Permission[];
}

@Injectable({ providedIn: 'root' })
export class RbacService {
  private roles: Map<string, Role> = new Map([
    ['admin', {
      name: 'admin',
      permissions: [
        { resource: 'users', actions: ['create', 'read', 'update', 'delete'] },
        { resource: 'posts', actions: ['create', 'read', 'update', 'delete'] },
        { resource: 'settings', actions: ['read', 'update'] }
      ]
    }],
    ['editor', {
      name: 'editor',
      permissions: [
        { resource: 'posts', actions: ['create', 'read', 'update'] },
        { resource: 'media', actions: ['create', 'read', 'delete'] }
      ]
    }],
    ['viewer', {
      name: 'viewer',
      permissions: [
        { resource: 'posts', actions: ['read'] },
        { resource: 'media', actions: ['read'] }
      ]
    }]
  ]);
  
  constructor(private authService: AuthService) {}
  
  hasPermission(resource: string, action: string): boolean {
    const user = this.authService.getCurrentUser();
    if (!user || !user.role) return false;
    
    const role = this.roles.get(user.role);
    if (!role) return false;
    
    const permission = role.permissions.find(p => p.resource === resource);
    return permission?.actions.includes(action) || false;
  }
  
  hasRole(roleName: string): boolean {
    const user = this.authService.getCurrentUser();
    return user?.role === roleName;
  }
  
  hasAnyRole(roles: string[]): boolean {
    const user = this.authService.getCurrentUser();
    return roles.includes(user?.role || '');
  }
}
```

### Permission Directive

```typescript
@Directive({
  selector: '[hasPermission]',
  standalone: true
})
export class HasPermissionDirective implements OnInit {
  @Input() hasPermission!: { resource: string; action: string };
  
  constructor(
    private rbac: RbacService,
    private templateRef: TemplateRef<any>,
    private viewContainer: ViewContainerRef
  ) {}
  
  ngOnInit() {
    const { resource, action } = this.hasPermission;
    
    if (this.rbac.hasPermission(resource, action)) {
      this.viewContainer.createEmbeddedView(this.templateRef);
    } else {
      this.viewContainer.clear();
    }
  }
}

// Usage
<button *hasPermission="{ resource: 'users', action: 'delete' }">
  Delete User
</button>
```

### Role Directive

```typescript
@Directive({
  selector: '[hasRole]',
  standalone: true
})
export class HasRoleDirective implements OnInit {
  @Input() hasRole!: string | string[];
  
  constructor(
    private rbac: RbacService,
    private templateRef: TemplateRef<any>,
    private viewContainer: ViewContainerRef
  ) {}
  
  ngOnInit() {
    const roles = Array.isArray(this.hasRole) ? this.hasRole : [this.hasRole];
    
    if (this.rbac.hasAnyRole(roles)) {
      this.viewContainer.createEmbeddedView(this.templateRef);
    } else {
      this.viewContainer.clear();
    }
  }
}

// Usage
<div *hasRole="'admin'">
  Admin content
</div>

<div *hasRole="['admin', 'editor']">
  Admin or Editor content
</div>
```

---

## HTTP Interceptors

### Auth Interceptor

```typescript
export const authInterceptor: HttpInterceptorFn = (req, next) => {
  const authService = inject(AuthService);
  const token = authService.getToken();
  
  // Skip auth for certain URLs
  if (req.url.includes('/auth/login') || req.url.includes('/auth/register')) {
    return next(req);
  }
  
  // Add auth token
  if (token) {
    req = req.clone({
      setHeaders: {
        Authorization: `Bearer ${token}`,
        'X-Requested-With': 'XMLHttpRequest'
      }
    });
  }
  
  return next(req).pipe(
    catchError((error: HttpErrorResponse) => {
      if (error.status === 401) {
        // Token expired or invalid
        authService.logout();
        inject(Router).navigate(['/login']);
      }
      return throwError(() => error);
    })
  );
};
```

### Token Refresh Interceptor

```typescript
export const tokenRefreshInterceptor: HttpInterceptorFn = (req, next) => {
  const authService = inject(AuthService);
  const tokenService = inject(TokenRefreshService);
  
  return next(req).pipe(
    catchError((error: HttpErrorResponse) => {
      if (error.status === 401 && !req.url.includes('/auth/refresh')) {
        // Try to refresh token
        return tokenService.refreshToken().pipe(
          switchMap(newToken => {
            // Retry request with new token
            const cloned = req.clone({
              setHeaders: {
                Authorization: `Bearer ${newToken}`
              }
            });
            return next(cloned);
          }),
          catchError(refreshError => {
            authService.logout();
            return throwError(() => refreshError);
          })
        );
      }
      return throwError(() => error);
    })
  );
};
```

---

## Session Management

### Session Service

```typescript
@Injectable({ providedIn: 'root' })
export class SessionService {
  private readonly TIMEOUT_DURATION = 30 * 60 * 1000; // 30 minutes
  private timeoutId: any;
  private lastActivity: number = Date.now();
  
  constructor(
    private authService: AuthService,
    private router: Router
  ) {
    this.startMonitoring();
  }
  
  private startMonitoring(): void {
    // Monitor user activity
    fromEvent(document, 'click').pipe(
      merge(
        fromEvent(document, 'keypress'),
        fromEvent(document, 'mousemove'),
        fromEvent(document, 'scroll')
      ),
      throttleTime(1000)
    ).subscribe(() => {
      this.resetTimeout();
    });
    
    this.resetTimeout();
  }
  
  private resetTimeout(): void {
    this.lastActivity = Date.now();
    
    // Clear existing timeout
    if (this.timeoutId) {
      clearTimeout(this.timeoutId);
    }
    
    // Set new timeout
    this.timeoutId = setTimeout(() => {
      this.handleTimeout();
    }, this.TIMEOUT_DURATION);
  }
  
  private handleTimeout(): void {
    console.log('Session timeout - logging out');
    this.authService.logout();
    this.router.navigate(['/login'], {
      queryParams: { reason: 'session_timeout' }
    });
  }
  
  getLastActivity(): Date {
    return new Date(this.lastActivity);
  }
  
  getRemainingTime(): number {
    const elapsed = Date.now() - this.lastActivity;
    return Math.max(0, this.TIMEOUT_DURATION - elapsed);
  }
}
```

---

## Best Practices

✅ **DO**:
- Use HTTPS for all auth endpoints
- Store tokens in HttpOnly cookies when possible
- Implement token refresh
- Use route guards for protected routes
- Validate tokens on server side
- Implement session timeout
- Log security events
- Use strong password policies

❌ **DON'T**:
- Store sensitive data in localStorage
- Send tokens in URL parameters
- Trust client-side validation alone
- Use weak encryption
- Expose user roles/permissions in JWT
- Skip CSRF protection
- Hardcode secrets in code

---

*Authenticate securely, authorize precisely! 🔐*