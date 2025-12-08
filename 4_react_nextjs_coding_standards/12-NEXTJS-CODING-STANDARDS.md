# 12. Next.js Coding Standards (Jupiter ec-nx-01)

## Overview

This document establishes coding standards for Next.js applications in the OElite platform, specifically for the development template `jupiter/ec-nx-01`. These standards ensure consistency, maintainability, and enterprise-grade quality across all Next.js eCommerce implementations.

**Technology Stack**: Next.js 14+, React 18+, TypeScript, Tailwind CSS, SWR, Framer Motion

## 🚨 **MANDATORY: No-Mock-Data Policy**

### **Strict Prohibition of Fake/Mock Data**

**CRITICAL REQUIREMENT**: React/Next.js developers MUST NEVER use fake, mock, or placeholder data values under any circumstances. This is a **mandatory requirement** with zero exceptions.

#### **Forbidden Practices** ❌

```tsx
// ❌ ABSOLUTELY FORBIDDEN - Fake/mock data
const ProductList: React.FC = () => {
  const [products, setProducts] = useState<Product[]>([
    { id: 1, name: 'Sample Product', price: 99.99 }, // FORBIDDEN
    { id: 2, name: 'Another Product', price: 149.99 } // FORBIDDEN
  ]);

  useEffect(() => {
    // ❌ FORBIDDEN - Using mock data as fallback
    fetch('/api/products')
      .then(res => res.json())
      .then(data => setProducts(data))
      .catch(err => {
        console.error('API failed, using mock data');
        setProducts(getMockProducts()); // ABSOLUTELY FORBIDDEN
      });
  }, []);

  return (
    <div>
      {products.map(product => (
        <ProductCard key={product.id} product={product} />
      ))}
    </div>
  );
};

const getMockProducts = (): Product[] => {
  return [{ id: 999, name: 'Mock Product', price: 0 }]; // FORBIDDEN
};
```

```tsx
// ❌ FORBIDDEN - Hard-coded mock values in components
const ProductCard: React.FC = () => {
  return (
    <div className="product-card">
      <h3>Sample Product Name</h3> {/* FORBIDDEN */}
      <p className="price">$99.99</p>   {/* FORBIDDEN */}
    </div>
  );
};

// ❌ FORBIDDEN - Mock data in development
const DevelopmentProducts: React.FC = () => {
  return (
    <div>
      <div className="mock-product">Mock Product for Development</div> {/* FORBIDDEN */}
    </div>
  );
};
```

#### **Required Implementation** ✅

```tsx
// ✅ CORRECT - Always request data from API endpoints using SWR
import useSWR from 'swr';

interface ApiResponse<T> {
  data: T;
  error?: string;
}

const fetcher = async (url: string): Promise<Product[]> => {
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`API Error: ${response.status} ${response.statusText}`);
  }
  return response.json();
};

const ProductList: React.FC = () => {
  const { data: products, error, isLoading } = useSWR<Product[]>(
    '/api/v1.0/products',
    fetcher,
    {
      revalidateOnFocus: false,
      revalidateOnReconnect: true,
      errorRetryCount: 3,
      errorRetryInterval: 1000
    }
  );

  if (isLoading) {
    return (
      <div className="flex items-center justify-center p-8">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary"></div>
        <span className="ml-2">Loading products...</span>
      </div>
    );
  }

  if (error) {
    return (
      <div className="bg-red-50 border border-red-200 rounded-md p-4">
        <div className="flex items-center">
          <div className="flex-shrink-0">
            <svg className="h-5 w-5 text-red-400" viewBox="0 0 20 20" fill="currentColor">
              <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clipRule="evenodd" />
            </svg>
          </div>
          <div className="ml-3">
            <h3 className="text-sm font-medium text-red-800">Unable to load products</h3>
            <p className="mt-2 text-sm text-red-700">
              Please check API endpoint configuration: {error.message}
            </p>
          </div>
        </div>
      </div>
    );
  }

  if (!products || products.length === 0) {
    return (
      <div className="text-center py-12">
        <svg className="mx-auto h-12 w-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M20 13V6a2 2 0 00-2-2H6a2 2 0 00-2 2v7m16 0v5a2 2 0 01-2 2H6a2 2 0 01-2 2m16-7H4" />
        </svg>
        <h3 className="mt-4 text-sm font-medium text-gray-900">No products available</h3>
        <p className="mt-2 text-sm text-gray-500">Please contact your administrator.</p>
      </div>
    );
  }

  return (
    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
      {products.map((product) => (
        <ProductCard key={product.id} product={product} />
      ))}
    </div>
  );
};
```

#### **Server-Side Data Fetching** ✅

```tsx
// ✅ CORRECT - Server-side data fetching with Next.js App Router
import { notFound } from 'next/navigation';

interface ProductPageProps {
  params: { id: string };
}

async function getProduct(id: string): Promise<Product | null> {
  try {
    const response = await fetch(`${process.env.API_BASE_URL}/api/v1.0/products/${id}`, {
      next: { revalidate: 60 }, // Cache for 60 seconds
      headers: {
        'Content-Type': 'application/json',
      },
    });

    if (!response.ok) {
      if (response.status === 404) {
        return null;
      }
      throw new Error(`Failed to fetch product: ${response.status}`);
    }

    return response.json();
  } catch (error) {
    console.error('Product fetch error:', error);
    throw error; // Let Next.js handle the error boundary
  }
}

export default async function ProductPage({ params }: ProductPageProps) {
  const product = await getProduct(params.id);

  if (!product) {
    notFound(); // Show 404 page
  }

  return (
    <div className="max-w-4xl mx-auto p-6">
      <h1 className="text-3xl font-bold text-gray-900">{product.name}</h1>
      <p className="mt-4 text-xl text-gray-600">${product.price}</p>
      <div className="mt-6">
        <img
          src={product.image}
          alt={product.name}
          className="w-full h-96 object-cover rounded-lg"
        />
      </div>
    </div>
  );
}
```

#### **Task Blocking Protocol** 🛑

When API endpoints are not available or properly configured:

1. **Mark Task as BLOCKED**: Do not proceed with component implementation
2. **Show User-Friendly Message**: Display clear blocking message
3. **Document API Requirements**: Specify exactly what endpoints are needed
4. **Wait for Unblocking**: Only mark task complete when API endpoints are available

```tsx
// ✅ CORRECT - Blocking pattern when API unavailable
const FeatureComponent: React.FC = () => {
  const [apiAvailable, setApiAvailable] = useState(false);
  const [isChecking, setIsChecking] = useState(true);

  useEffect(() => {
    checkApiEndpoints();
  }, []);

  const checkApiEndpoints = async () => {
    setIsChecking(true);
    try {
      // Check if required APIs are available
      const endpoints = [
        '/api/v1.0/products',
        '/api/v1.0/categories'
      ];

      const checks = await Promise.all(
        endpoints.map(endpoint =>
          fetch(endpoint, { method: 'HEAD' })
            .then(res => res.ok)
            .catch(() => false)
        )
      );

      setApiAvailable(checks.every(check => check));
    } catch (error) {
      setApiAvailable(false);
    } finally {
      setIsChecking(false);
    }
  };

  if (isChecking) {
    return (
      <div className="flex items-center justify-center p-8">
        <div className="animate-spin rounded-full h-6 w-6 border-b-2 border-primary mr-2"></div>
        <span>Checking API availability...</span>
      </div>
    );
  }

  if (!apiAvailable) {
    return (
      <div className="bg-yellow-50 border border-yellow-200 rounded-md p-6">
        <div className="flex items-start">
          <div className="flex-shrink-0">
            <svg className="h-6 w-6 text-yellow-400" fill="currentColor" viewBox="0 0 20 20">
              <path fillRule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clipRule="evenodd" />
            </svg>
          </div>
          <div className="ml-3">
            <h3 className="text-lg font-medium text-yellow-800">Development Blocked</h3>
            <p className="mt-2 text-sm text-yellow-700">
              This component requires the following API endpoints:
            </p>
            <ul className="mt-2 text-sm text-yellow-700 list-disc list-inside">
              <li><code className="bg-yellow-100 px-1 rounded">GET /api/v1.0/products</code> - Product listing</li>
              <li><code className="bg-yellow-100 px-1 rounded">GET /api/v1.0/categories</code> - Category data</li>
            </ul>
            <p className="mt-4 text-sm text-yellow-700">
              Please provide API endpoint contracts to continue development.
            </p>
            <button
              onClick={checkApiEndpoints}
              className="mt-4 bg-yellow-600 text-white px-4 py-2 rounded-md text-sm hover:bg-yellow-700 focus:outline-none focus:ring-2 focus:ring-yellow-500"
            >
              Retry API Connection
            </button>
          </div>
        </div>
      </div>
    );
  }

  // Component implementation when APIs are available
  return (
    <div>
      {/* Your component implementation here */}
    </div>
  );
};
```

#### **Development Workflow** 📋

1. **API-First Development**: Always request API contracts before starting component development
2. **SWR Integration**: Use SWR for client-side data fetching with proper error handling
3. **Server Components**: Leverage Next.js App Router for server-side data fetching when appropriate
4. **Error Boundaries**: Implement React error boundaries for graceful error handling
5. **Loading States**: Show loading indicators during data fetching
6. **Empty States**: Handle scenarios when API returns empty data
7. **Type Safety**: Use TypeScript interfaces for all API responses

#### **Quality Gate Enforcement** ⚡

This policy is enforced by Arc-Agents quality gates. Any code containing mock data will fail quality checks and prevent task completion.

**Validation Rules:**
- Scan for hard-coded data arrays with realistic-looking values
- Check for mock/fake data generation functions
- Validate that all data comes from API calls (fetch, SWR, or server actions)
- Ensure proper error handling without mock fallbacks
- Verify proper TypeScript typing for API responses

**Remember**: Mock data in production causes serious confusion and incidents. Always use real API endpoints or show appropriate blocked/error states.

## 🎯 **Critical UI Implementation Practices**

### **Mandatory Requirements for All Next.js Applications**

The following practices are **MANDATORY** for all OElite Next.js applications to ensure professional, maintainable, and user-friendly interfaces.

### 1. **Responsive Design with Mobile-First Approach** 🚨

#### **MANDATORY: Mobile-First Development with Tailwind CSS**

All components MUST be designed mobile-first and scale up to larger screens using Tailwind's responsive utilities:

```tsx
// ✅ CORRECT - Mobile-first approach with Tailwind CSS
export const ProductCard = ({ product }: { product: Product }) => {
  return (
    <div className="
      p-2 text-sm               // Mobile (default)
      md:p-4 md:text-base       // Tablet and up
      lg:p-6 lg:text-lg         // Desktop and up
      xl:p-8 xl:text-xl         // Large screens
      bg-white shadow-md rounded-lg
    ">
      <img
        src={product.image}
        alt={product.name}
        className="
          w-full h-32            // Mobile height
          md:h-48               // Tablet height
          lg:h-64               // Desktop height
          object-cover rounded-md
        "
      />
      <h3 className="
        mt-2 font-medium        // Mobile spacing
        md:mt-4 md:font-semibold // Tablet+ spacing and weight
      ">
        {product.name}
      </h3>
    </div>
  );
};

// ❌ FORBIDDEN - Desktop-first approach
export const BadProductCard = ({ product }: { product: Product }) => {
  return (
    <div className="
      p-8 text-xl             // Desktop as default
      md:p-2 md:text-sm       // Mobile as afterthought
    ">
      {/* This is backwards! */}
    </div>
  );
};
```

#### **MANDATORY: CSS Grid and Flexbox Patterns**

Use responsive grid layouts with proper breakpoints:

```tsx
// ✅ CORRECT - Responsive grid layout
export const ProductGrid = ({ products }: { products: Product[] }) => {
  return (
    <div className="
      grid
      grid-cols-1           // 1 column on mobile
      md:grid-cols-2        // 2 columns on tablet
      lg:grid-cols-3        // 3 columns on desktop
      xl:grid-cols-4        // 4 columns on large screens
      gap-4 md:gap-6        // Responsive gap
      p-4 md:p-6
    ">
      {products.map((product) => (
        <ProductCard key={product.id} product={product} />
      ))}
    </div>
  );
};

// ✅ CORRECT - Flexbox navigation with responsive behavior
export const Navigation = () => {
  return (
    <nav className="
      flex flex-col          // Stack vertically on mobile
      md:flex-row           // Horizontal on tablet+
      md:items-center       // Center align on larger screens
      gap-2 md:gap-6        // Responsive spacing
    ">
      <Link href="/" className="py-2 md:py-0">Home</Link>
      <Link href="/products" className="py-2 md:py-0">Products</Link>
      <Link href="/cart" className="py-2 md:py-0">Cart</Link>
    </nav>
  );
};
```

#### **React Hooks for Responsive Logic**

```tsx
// ✅ CORRECT - Custom hook for responsive behavior
import { useState, useEffect } from 'react';

export const useMediaQuery = (query: string): boolean => {
  const [matches, setMatches] = useState(false);

  useEffect(() => {
    const media = window.matchMedia(query);
    if (media.matches !== matches) {
      setMatches(media.matches);
    }

    const listener = () => setMatches(media.matches);
    media.addListener(listener);

    return () => media.removeListener(listener);
  }, [matches, query]);

  return matches;
};

export const useBreakpoints = () => {
  const isMobile = useMediaQuery('(max-width: 767px)');
  const isTablet = useMediaQuery('(min-width: 768px) and (max-width: 1023px)');
  const isDesktop = useMediaQuery('(min-width: 1024px)');

  return { isMobile, isTablet, isDesktop };
};

// ✅ Usage in components
export const ResponsiveProductGrid = ({ products }: { products: Product[] }) => {
  const { isMobile, isTablet, isDesktop } = useBreakpoints();

  const itemsPerPage = isMobile ? 4 : isTablet ? 8 : 12;

  return (
    <div className={`
      grid gap-4
      ${isMobile ? 'grid-cols-1' : isTablet ? 'grid-cols-2' : 'grid-cols-3'}
    `}>
      {products.slice(0, itemsPerPage).map((product) => (
        <ProductCard
          key={product.id}
          product={product}
          layout={isMobile ? 'compact' : 'full'}
        />
      ))}
    </div>
  );
};
```

### 2. **Mobile-Specific Component Strategy** 📱

#### **When to Create Mobile-Specific Components**

Create dedicated mobile components when:
- Desktop UI cannot be reasonably adapted for mobile
- Mobile requires fundamentally different interaction patterns
- Performance optimization is needed for mobile devices

```tsx
// ✅ CORRECT - Mobile-specific navigation
export const MobileNavigation = () => {
  const [isOpen, setIsOpen] = useState(false);

  return (
    <div className="md:hidden">
      {/* Touch-optimized hamburger button */}
      <button
        onClick={() => setIsOpen(!isOpen)}
        className="
          relative w-8 h-8
          focus:outline-none focus:ring-2 focus:ring-blue-500
          aria-expanded={isOpen}
        "
        aria-label="Toggle menu"
      >
        <div className="absolute inset-0 flex flex-col justify-center space-y-1">
          <span className={`
            h-0.5 w-6 bg-gray-600 transition-all duration-300
            ${isOpen ? 'rotate-45 translate-y-1' : ''}
          `} />
          <span className={`
            h-0.5 w-6 bg-gray-600 transition-all duration-300
            ${isOpen ? 'opacity-0' : 'opacity-100'}
          `} />
          <span className={`
            h-0.5 w-6 bg-gray-600 transition-all duration-300
            ${isOpen ? '-rotate-45 -translate-y-1' : ''}
          `} />
        </div>
      </button>

      {/* Full-screen mobile menu */}
      {isOpen && (
        <div className="
          fixed inset-0 z-50 bg-white
          flex flex-col items-center justify-center
          space-y-8 text-xl font-medium
        ">
          <Link href="/" onClick={() => setIsOpen(false)}>
            Home
          </Link>
          <Link href="/products" onClick={() => setIsOpen(false)}>
            Products
          </Link>
          <Link href="/cart" onClick={() => setIsOpen(false)}>
            Cart
          </Link>
          <button
            onClick={() => setIsOpen(false)}
            className="absolute top-4 right-4 w-8 h-8"
          >
            ✕
          </button>
        </div>
      )}
    </div>
  );
};

// ✅ CORRECT - Desktop navigation (separate component)
export const DesktopNavigation = () => {
  return (
    <nav className="hidden md:flex items-center space-x-6">
      <Link href="/" className="hover:text-blue-600">Home</Link>
      <Link href="/products" className="hover:text-blue-600">Products</Link>
      <Link href="/cart" className="hover:text-blue-600">Cart</Link>
    </nav>
  );
};
```

#### **Component Substitution Pattern**

```tsx
// ✅ CORRECT - Conditional component rendering
export const Header = () => {
  const { isMobile } = useBreakpoints();

  return (
    <header className="bg-white shadow-sm">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex justify-between items-center h-16">
          <Logo />

          {/* Conditional navigation rendering */}
          {isMobile ? <MobileNavigation /> : <DesktopNavigation />}

          <UserActions />
        </div>
      </div>
    </header>
  );
};

// ✅ CORRECT - CSS-based component substitution
export const ProductDisplay = ({ products }: { products: Product[] }) => {
  return (
    <>
      {/* Mobile: Card layout */}
      <div className="md:hidden">
        <MobileProductCards products={products} />
      </div>

      {/* Desktop: Table layout */}
      <div className="hidden md:block">
        <ProductTable products={products} />
      </div>
    </>
  );
};
```

### 3. **Architectural Modularity and Reusability** 🏗️

#### **MANDATORY: Reusable Component Design**

Design components to be modular and reusable across different contexts:

```tsx
// ✅ CORRECT - Generic, reusable modal component
interface ModalProps {
  isOpen: boolean;
  onClose: () => void;
  title?: string;
  size?: 'sm' | 'md' | 'lg' | 'xl';
  showCloseButton?: boolean;
  closeOnOverlayClick?: boolean;
  children: React.ReactNode;
  footer?: React.ReactNode;
}

export const Modal = ({
  isOpen,
  onClose,
  title,
  size = 'md',
  showCloseButton = true,
  closeOnOverlayClick = true,
  children,
  footer
}: ModalProps) => {
  if (!isOpen) return null;

  const sizeClasses = {
    sm: 'max-w-md',
    md: 'max-w-lg',
    lg: 'max-w-2xl',
    xl: 'max-w-4xl'
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center">
      {/* Overlay */}
      <div
        className="fixed inset-0 bg-black bg-opacity-50"
        onClick={closeOnOverlayClick ? onClose : undefined}
      />

      {/* Modal content */}
      <div className={`
        relative bg-white rounded-lg shadow-xl
        w-full mx-4 ${sizeClasses[size]}
        max-h-[90vh] flex flex-col
      `}>
        {/* Header */}
        {(title || showCloseButton) && (
          <div className="flex items-center justify-between p-6 border-b">
            {title && (
              <h2 className="text-xl font-semibold text-gray-900">
                {title}
              </h2>
            )}
            {showCloseButton && (
              <button
                onClick={onClose}
                className="text-gray-400 hover:text-gray-600"
              >
                ✕
              </button>
            )}
          </div>
        )}

        {/* Body */}
        <div className="flex-1 p-6 overflow-y-auto">
          {children}
        </div>

        {/* Footer */}
        {footer && (
          <div className="flex justify-end gap-3 p-6 border-t">
            {footer}
          </div>
        )}
      </div>
    </div>
  );
};

// ✅ Usage examples
// Product details modal
// <Modal
//   isOpen={showProductDetails}
//   onClose={() => setShowProductDetails(false)}
//   title="Product Details"
//   size="lg"
//   footer={
//     <button className="btn-primary" onClick={addToCart}>
//       Add to Cart
//     </button>
//   }
// >
//   <ProductDetails product={selectedProduct} />
// </Modal>

// Confirmation modal
// <Modal
//   isOpen={showConfirmation}
//   onClose={() => setShowConfirmation(false)}
//   title="Confirm Action"
//   size="sm"
//   footer={
//     <>
//       <button className="btn-secondary" onClick={cancel}>Cancel</button>
//       <button className="btn-danger" onClick={confirm}>Delete</button>
//     </>
//   }
// >
//   <p>Are you sure you want to delete this item?</p>
// </Modal>
```

#### **Generic TreeView Component**

```tsx
// ✅ CORRECT - Generic, reusable tree component
interface TreeNode<T = any> {
  id: string;
  label: string;
  data?: T;
  children?: TreeNode<T>[];
  expanded?: boolean;
  selected?: boolean;
  icon?: string;
}

interface TreeViewProps<T> {
  nodes: TreeNode<T>[];
  multiSelect?: boolean;
  onNodeSelect?: (node: TreeNode<T>) => void;
  onNodeToggle?: (node: TreeNode<T>) => void;
  className?: string;
}

export const TreeView = <T,>({
  nodes,
  multiSelect = false,
  onNodeSelect,
  onNodeToggle,
  className = ''
}: TreeViewProps<T>) => {
  return (
    <div className={`tree-view ${className}`}>
      {nodes.map((node) => (
        <TreeNode
          key={node.id}
          node={node}
          level={0}
          onSelect={onNodeSelect}
          onToggle={onNodeToggle}
        />
      ))}
    </div>
  );
};

const TreeNode = <T,>({
  node,
  level,
  onSelect,
  onToggle
}: {
  node: TreeNode<T>;
  level: number;
  onSelect?: (node: TreeNode<T>) => void;
  onToggle?: (node: TreeNode<T>) => void;
}) => {
  const handleToggle = () => {
    if (node.children?.length) {
      onToggle?.(node);
    }
  };

  return (
    <div className="tree-node">
      <div
        className={`
          flex items-center py-2 px-2 cursor-pointer
          hover:bg-gray-50
          ${node.selected ? 'bg-blue-50 text-blue-700' : ''}
        `}
        style={{ paddingLeft: `${level * 20 + 8}px` }}
        onClick={() => onSelect?.(node)}
      >
        {node.children?.length ? (
          <button
            onClick={handleToggle}
            className="mr-2 w-4 h-4 flex items-center justify-center"
          >
            {node.expanded ? '−' : '+'}
          </button>
        ) : (
          <div className="w-4 h-4 mr-2" />
        )}

        {node.icon && <span className="mr-2">{node.icon}</span>}
        <span>{node.label}</span>
      </div>

      {node.expanded && node.children && (
        <div>
          {node.children.map((child) => (
            <TreeNode
              key={child.id}
              node={child}
              level={level + 1}
              onSelect={onSelect}
              onToggle={onToggle}
            />
          ))}
        </div>
      )}
    </div>
  );
};

// ✅ Usage for different business domains

// Category navigation
// <TreeView
//   nodes={categoryTree}
//   onNodeSelect={selectCategory}
// />

// Organization structure
// <TreeView
//   nodes={organizationTree}
//   multiSelect={true}
//   onNodeSelect={selectDepartment}
// />
```

### 4. **Object-Oriented Design - No Hard Coding** 🎯

#### **Configuration Classes and Constants**

```typescript
// ✅ CORRECT - Centralized configuration
export class AppConfig {
  static readonly API_ENDPOINTS = {
    PRODUCTS: '/api/products',
    CUSTOMERS: '/api/customers',
    ORDERS: '/api/orders',
    AUTH: '/api/auth'
  } as const;

  static readonly UI_CONSTANTS = {
    PAGINATION_SIZE: 20,
    MOBILE_BREAKPOINT: 768,
    TOAST_DURATION: 3000,
    DEBOUNCE_DELAY: 300
  } as const;

  static readonly ROUTES = {
    HOME: '/',
    PRODUCTS: '/products',
    PRODUCT_DETAIL: '/products/[id]',
    CART: '/cart',
    CHECKOUT: '/checkout',
    PROFILE: '/profile'
  } as const;

  static readonly BREAKPOINTS = {
    SM: '640px',
    MD: '768px',
    LG: '1024px',
    XL: '1280px'
  } as const;
}

// ❌ FORBIDDEN - Hard-coded values in components
export const BadComponent = () => {
  const [isMobile, setIsMobile] = useState(window.innerWidth <= 768); // FORBIDDEN!

  const fetchData = () => {
    fetch('/api/products'); // FORBIDDEN!
  };

  return (
    <div className="p-4"> {/* Better to use configured values */}
      {/* Component content */}
    </div>
  );
};
```

#### **Environment-Based Configuration**

```typescript
// ✅ CORRECT - Environment configuration service
interface AppEnvironment {
  apiUrl: string;
  apiTimeout: number;
  features: {
    wishlist: boolean;
    comparison: boolean;
    reviews: boolean;
    analytics: boolean;
  };
  ui: {
    theme: 'light' | 'dark' | 'auto';
    itemsPerPage: number;
    enableAnimations: boolean;
  };
  external: {
    stripePublicKey: string;
    googleAnalyticsId?: string;
    hotjarId?: string;
  };
}

class ConfigurationService {
  private static instance: ConfigurationService;
  private config: AppEnvironment;

  private constructor() {
    this.config = {
      apiUrl: process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3000',
      apiTimeout: parseInt(process.env.NEXT_PUBLIC_API_TIMEOUT || '5000'),
      features: {
        wishlist: process.env.NEXT_PUBLIC_ENABLE_WISHLIST === 'true',
        comparison: process.env.NEXT_PUBLIC_ENABLE_COMPARISON === 'true',
        reviews: process.env.NEXT_PUBLIC_ENABLE_REVIEWS === 'true',
        analytics: process.env.NEXT_PUBLIC_ENABLE_ANALYTICS === 'true'
      },
      ui: {
        theme: (process.env.NEXT_PUBLIC_DEFAULT_THEME as any) || 'light',
        itemsPerPage: parseInt(process.env.NEXT_PUBLIC_ITEMS_PER_PAGE || '20'),
        enableAnimations: process.env.NEXT_PUBLIC_ENABLE_ANIMATIONS !== 'false'
      },
      external: {
        stripePublicKey: process.env.NEXT_PUBLIC_STRIPE_PUBLIC_KEY || '',
        googleAnalyticsId: process.env.NEXT_PUBLIC_GA_ID,
        hotjarId: process.env.NEXT_PUBLIC_HOTJAR_ID
      }
    };
  }

  public static getInstance(): ConfigurationService {
    if (!ConfigurationService.instance) {
      ConfigurationService.instance = new ConfigurationService();
    }
    return ConfigurationService.instance;
  }

  public getApiConfig() { return this.config; }
  public getFeatureConfig() { return this.config.features; }
  public getUIConfig() { return this.config.ui; }
  public getExternalConfig() { return this.config.external; }
}

export const appConfig = ConfigurationService.getInstance();
```

#### **Type-Safe Translation Keys**

```typescript
// ✅ CORRECT - Centralized, type-safe translation keys
export const TRANSLATION_KEYS = {
  COMMON: {
    SAVE: 'common.save',
    CANCEL: 'common.cancel',
    DELETE: 'common.delete',
    CONFIRM: 'common.confirm',
    LOADING: 'common.loading',
    ERROR: 'common.error'
  },
  PRODUCTS: {
    TITLE: 'products.title',
    ADD_TO_CART: 'products.addToCart',
    OUT_OF_STOCK: 'products.outOfStock',
    PRICE_LABEL: 'products.priceLabel',
    DESCRIPTION: 'products.description'
  },
  CART: {
    TITLE: 'cart.title',
    EMPTY: 'cart.empty',
    TOTAL: 'cart.total',
    CHECKOUT: 'cart.checkout'
  },
  ERRORS: {
    NETWORK: 'errors.network',
    VALIDATION: 'errors.validation',
    NOT_FOUND: 'errors.notFound',
    UNAUTHORIZED: 'errors.unauthorized'
  }
} as const;

// ✅ Type-safe translation hook
export const useTranslation = () => {
  const { t } = useTranslation(); // Assuming next-i18next or similar

  return {
    t: (key: keyof typeof TRANSLATION_KEYS[keyof typeof TRANSLATION_KEYS]) => t(key)
  };
};

// ✅ Usage in components
export const ProductCard = ({ product }: { product: Product }) => {
  const { t } = useTranslation();

  return (
    <div className="product-card">
      <h3>{product.name}</h3>
      <p>{t(TRANSLATION_KEYS.PRODUCTS.PRICE_LABEL)}: ${product.price}</p>
      <button disabled={!product.inStock}>
        {product.inStock
          ? t(TRANSLATION_KEYS.PRODUCTS.ADD_TO_CART)
          : t(TRANSLATION_KEYS.PRODUCTS.OUT_OF_STOCK)
        }
      </button>
    </div>
  );
};
```

### 5. **Centralized Non-UI Code Organization** 📚

#### **Business Domain Library Structure**

```
src/lib/
├── core/                    # Core utilities
│   ├── api/                # API utilities and clients
│   ├── auth/               # Authentication logic
│   ├── cache/              # Caching strategies
│   ├── error/              # Error handling
│   ├── hooks/              # Shared React hooks
│   ├── storage/            # Local/session storage
│   └── validation/         # Common validation
├── domains/                # Business domains
│   ├── products/
│   │   ├── types/          # Product interfaces/types
│   │   ├── api/            # Product API functions
│   │   ├── hooks/          # Product-specific hooks
│   │   ├── utils/          # Product utilities
│   │   ├── validation/     # Product validation
│   │   └── index.ts        # Public API
│   ├── customers/
│   │   ├── types/
│   │   ├── api/
│   │   ├── hooks/
│   │   ├── utils/
│   │   └── index.ts
│   ├── orders/
│   │   ├── types/
│   │   ├── api/
│   │   ├── hooks/
│   │   ├── utils/
│   │   └── index.ts
│   └── payments/
│       ├── types/
│       ├── api/
│       ├── hooks/
│       ├── utils/
│       └── index.ts
└── shared/                 # Shared utilities
    ├── types/              # Common TypeScript types
    ├── constants/          # Application constants
    ├── utils/              # General purpose utilities
    ├── hooks/              # Shared React hooks
    └── validation/         # Common validation schemas
```

#### **Domain-Specific API Functions**

```typescript
// ✅ src/lib/domains/products/api/product-api.ts
interface ProductQuery {
  page?: number;
  limit?: number;
  category?: string;
  search?: string;
  sortBy?: 'name' | 'price' | 'popularity';
  sortOrder?: 'asc' | 'desc';
}

export class ProductAPI {
  private static baseUrl = appConfig.getApiConfig().apiUrl;

  static async getProducts(params: ProductQuery): Promise<Product[]> {
    const searchParams = new URLSearchParams();
    Object.entries(params).forEach(([key, value]) => {
      if (value !== undefined) searchParams.set(key, value.toString());
    });

    const response = await fetch(
      `${this.baseUrl}${AppConfig.API_ENDPOINTS.PRODUCTS}?${searchParams}`
    );

    if (!response.ok) {
      throw new Error(`Failed to fetch products: ${response.statusText}`);
    }

    return response.json();
  }

  static async getProductById(id: string): Promise<Product> {
    const response = await fetch(
      `${this.baseUrl}${AppConfig.API_ENDPOINTS.PRODUCTS}/${id}`
    );

    if (!response.ok) {
      throw new Error(`Failed to fetch product: ${response.statusText}`);
    }

    return response.json();
  }

  static async searchProducts(query: string): Promise<Product[]> {
    return this.getProducts({ search: query });
  }
}

// ✅ src/lib/domains/products/hooks/use-products.ts
export const useProducts = (query: ProductQuery = {}) => {
  return useSWR(
    ['products', query],
    () => ProductAPI.getProducts(query),
    {
      revalidateOnFocus: false,
      dedupingInterval: 60000 // 1 minute
    }
  );
};

export const useProduct = (id: string) => {
  return useSWR(
    id ? ['product', id] : null,
    () => ProductAPI.getProductById(id),
    {
      revalidateOnFocus: false
    }
  );
};

// ✅ src/lib/domains/products/utils/product-utils.ts
export class ProductUtils {
  static formatPrice(price: number, currency = 'USD'): string {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency
    }).format(price);
  }

  static calculateDiscount(originalPrice: number, salePrice: number): number {
    return Math.round(((originalPrice - salePrice) / originalPrice) * 100);
  }

  static isInStock(product: Product): boolean {
    return product.status === ProductStatus.ACTIVE && product.stockQuantity > 0;
  }

  static getImageUrl(product: Product, size: 'thumb' | 'medium' | 'large' = 'medium'): string {
    const baseUrl = appConfig.getApiConfig().apiUrl;
    return `${baseUrl}/images/products/${product.id}/${size}/${product.mainImage}`;
  }

  static generateProductSlug(name: string): string {
    return name
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/(^-|-$)/g, '');
  }
}
```

#### **NPM Package Preparation**

```typescript
// ✅ src/lib/domains/products/index.ts - Clean public API
export { ProductAPI } from './api/product-api';
export { useProducts, useProduct, useProductSearch } from './hooks/use-products';
export { ProductUtils } from './utils/product-utils';
export { ProductValidation } from './validation/product-validation';

// Export types
export type {
  Product,
  ProductQuery,
  ProductStatus,
  ProductCategory,
  ProductImage,
  ProductVariant
} from './types/product.types';

// ✅ package.json structure for potential extraction
{
  "name": "@oelite/products-lib",
  "version": "1.0.0",
  "main": "dist/index.js",
  "module": "dist/index.esm.js",
  "types": "dist/index.d.ts",
  "exports": {
    ".": {
      "import": "./dist/index.esm.js",
      "require": "./dist/index.js"
    },
    "./api": "./dist/api/index.js",
    "./hooks": "./dist/hooks/index.js",
    "./utils": "./dist/utils/index.js",
    "./types": "./dist/types/index.js"
  },
  "peerDependencies": {
    "react": "^18.0.0",
    "swr": "^2.0.0"
  }
}
```

### 6. **Framework-Specific Best Practices** ⚡

#### **Next.js Performance Optimization**

```tsx
// ✅ CORRECT - Dynamic imports for code splitting
import dynamic from 'next/dynamic';

// Lazy load heavy components
const ProductReviews = dynamic(() => import('../ProductReviews'), {
  loading: () => <div className="animate-pulse bg-gray-200 h-32 rounded" />,
  ssr: false // Skip SSR for client-only components
});

const ChartComponent = dynamic(() => import('../ChartComponent'), {
  loading: () => <div>Loading chart...</div>
});

// ✅ CORRECT - Image optimization
import Image from 'next/image';

export const ProductImage = ({ product }: { product: Product }) => {
  return (
    <Image
      src={ProductUtils.getImageUrl(product, 'large')}
      alt={product.name}
      width={600}
      height={400}
      placeholder="blur"
      blurDataURL="data:image/jpeg;base64,..."
      className="rounded-lg object-cover"
      priority={false} // Only set to true for above-the-fold images
    />
  );
};

// ✅ CORRECT - Font optimization
import { Inter, Roboto } from 'next/font/google';

const inter = Inter({
  subsets: ['latin'],
  display: 'swap',
  variable: '--font-inter'
});

const roboto = Roboto({
  weight: ['400', '500', '700'],
  subsets: ['latin'],
  display: 'swap',
  variable: '--font-roboto'
});
```

#### **Server Components vs Client Components**

```tsx
// ✅ CORRECT - Server component for data fetching
// app/products/page.tsx
export default async function ProductsPage({
  searchParams
}: {
  searchParams: { category?: string; page?: string }
}) {
  // Server-side data fetching
  const products = await ProductAPI.getProducts({
    category: searchParams.category,
    page: parseInt(searchParams.page || '1')
  });

  return (
    <div>
      <h1>Products</h1>
      <ProductGrid products={products} />
    </div>
  );
}

// ✅ CORRECT - Client component for interactivity
'use client';

import { useState } from 'react';

export const ProductFilter = ({ onFilterChange }: {
  onFilterChange: (filters: ProductQuery) => void
}) => {
  const [filters, setFilters] = useState<ProductQuery>({});

  const handleFilterChange = (key: keyof ProductQuery, value: any) => {
    const newFilters = { ...filters, [key]: value };
    setFilters(newFilters);
    onFilterChange(newFilters);
  };

  return (
    <div className="space-y-4">
      {/* Interactive filter controls */}
    </div>
  );
};

// ✅ CORRECT - Composition of server and client components
// app/products/page.tsx
export default async function ProductsPage() {
  const products = await ProductAPI.getProducts({});

  return (
    <div className="flex">
      {/* Client component for filters */}
      <ProductFilter onFilterChange={handleFilterChange} />

      {/* Server component for product list */}
      <ProductGrid products={products} />
    </div>
  );
}
```

#### **State Management Best Practices**

```tsx
// ✅ CORRECT - Context for global state
interface CartContextType {
  items: CartItem[];
  addItem: (product: Product, quantity?: number) => void;
  removeItem: (productId: string) => void;
  updateQuantity: (productId: string, quantity: number) => void;
  clearCart: () => void;
  total: number;
}

const CartContext = createContext<CartContextType | undefined>(undefined);

export const CartProvider = ({ children }: { children: React.ReactNode }) => {
  const [items, setItems] = useState<CartItem[]>([]);

  const addItem = useCallback((product: Product, quantity = 1) => {
    setItems(prev => {
      const existingItem = prev.find(item => item.product.id === product.id);
      if (existingItem) {
        return prev.map(item =>
          item.product.id === product.id
            ? { ...item, quantity: item.quantity + quantity }
            : item
        );
      }
      return [...prev, { product, quantity }];
    });
  }, []);

  const total = useMemo(() =>
    items.reduce((sum, item) => sum + (item.product.price * item.quantity), 0),
    [items]
  );

  return (
    <CartContext.Provider value={{
      items,
      addItem,
      removeItem,
      updateQuantity,
      clearCart,
      total
    }}>
      {children}
    </CartContext.Provider>
  );
};

export const useCart = () => {
  const context = useContext(CartContext);
  if (!context) {
    throw new Error('useCart must be used within CartProvider');
  }
  return context;
};

// ✅ CORRECT - Custom hooks for complex state logic
export const useProductSearch = () => {
  const [query, setQuery] = useState('');
  const [filters, setFilters] = useState<ProductQuery>({});
  const [debouncedQuery, setDebouncedQuery] = useState('');

  // Debounce search query
  useEffect(() => {
    const timer = setTimeout(() => {
      setDebouncedQuery(query);
    }, AppConfig.UI_CONSTANTS.DEBOUNCE_DELAY);

    return () => clearTimeout(timer);
  }, [query]);

  const { data: products, error, isLoading } = useSWR(
    ['products', debouncedQuery, filters],
    () => ProductAPI.searchProducts(debouncedQuery, filters)
  );

  return {
    query,
    setQuery,
    filters,
    setFilters,
    products,
    error,
    isLoading
  };
};
```

## Project Architecture Standards

### 1. **Directory Structure** (Mandatory)

Follow the established OElite Next.js architecture:

```
src/
├── app/                    # Next.js 14 App Router
│   ├── [domain]/          # Multi-tenant routing
│   │   └── [lang]/        # Internationalization
│   ├── api/               # API routes
│   ├── globals.css        # Global styles
│   ├── layout.tsx         # Root layout
│   ├── not-found.tsx      # 404 page
│   └── error.tsx          # Error boundary
├── components/            # Reusable UI components
│   ├── Footer/            # Site footer
│   ├── Header/            # Site header
│   ├── Form/              # Form components
│   └── [Template]/        # Template-specific components
├── context/               # React context providers
├── data/                  # Static data and configurations
├── lib/                   # Utility functions and configurations
│   ├── api/               # API utilities
│   ├── utils/             # Helper functions
│   └── hooks/             # Custom React hooks
├── store/                 # State management
├── styles/                # SCSS/CSS modules
├── type/                  # TypeScript definitions
└── middleware.ts          # Next.js middleware
```

### 2. **App Router Structure** ✅

Use Next.js 14 App Router with proper organization:

```typescript
// ✅ CORRECT - Multi-tenant layout structure
// src/app/[domain]/[lang]/layout.tsx
export default function DomainLangLayout({
  children,
  params,
}: {
  children: React.ReactNode;
  params: { domain: string; lang: string };
}) {
  return (
    <html lang={params.lang}>
      <body>
        <DomainProvider domain={params.domain}>
          <LanguageProvider language={params.lang}>
            <Header />
            <main>{children}</main>
            <Footer />
          </LanguageProvider>
        </DomainProvider>
      </body>
    </html>
  );
}
```

### 3. **Forbidden Patterns** ❌

```typescript
// ❌ FORBIDDEN - Pages router in App Router project
pages/index.tsx

// ❌ FORBIDDEN - Mixed routing patterns
src/app/products/page.tsx  // App Router
src/pages/about.tsx        // Pages Router

// ❌ FORBIDDEN - Direct API calls in components
const data = await fetch('/api/products'); // Should use hooks/SWR
```

## Component Standards

### 1. **Component Architecture** ✅

Follow React best practices with Next.js optimization:

```typescript
// ✅ CORRECT - Functional component with proper typing
'use client';

import React, { useState, useCallback } from 'react';
import Image from 'next/image';
import Link from 'next/link';
import { motion } from 'framer-motion';
import { Product } from '@/type/product';
import { useCart } from '@/context/CartContext';

interface ProductCardProps {
  product: Product;
  className?: string;
  showQuickView?: boolean;
  onQuickView?: (product: Product) => void;
}

const ProductCard: React.FC<ProductCardProps> = ({
  product,
  className = '',
  showQuickView = true,
  onQuickView
}) => {
  const [isLoading, setIsLoading] = useState(false);
  const { addToCart } = useCart();

  const handleAddToCart = useCallback(async () => {
    setIsLoading(true);
    try {
      await addToCart(product);
    } catch (error) {
      console.error('Failed to add to cart:', error);
    } finally {
      setIsLoading(false);
    }
  }, [product, addToCart]);

  const handleQuickView = useCallback(() => {
    onQuickView?.(product);
  }, [product, onQuickView]);

  return (
    <motion.article
      className={`product-card ${className}`}
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.3 }}
    >
      <div className="product-card__image-wrapper relative overflow-hidden rounded-lg">
        <Link href={`/products/${product.slug}`}>
          <Image
            src={product.imageUrl}
            alt={product.name}
            width={400}
            height={400}
            className="product-card__image w-full h-auto object-cover transition-transform duration-300 hover:scale-105"
            priority={false}
            placeholder="blur"
            blurDataURL="data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAYEBQYFBAYGBQYHBwYIChAKCgkJChQODwwQFxQYGBcUFhYaHSUfGhsjHBYWICwgIyYnKSopGR8tMC0oMCUoKSj/2wBDAQcHBwoIChMKChMoGhYaKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCj/wAARCAABAAEDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAv/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/8QAFQEBAQAAAAAAAAAAAAAAAAAAAAX/xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oADAMBAAIRAxEAPwCdABmX/9k="
          />
        </Link>

        {showQuickView && (
          <button
            type="button"
            className="product-card__quick-view absolute top-2 right-2 bg-white p-2 rounded-full shadow-md opacity-0 group-hover:opacity-100 transition-opacity duration-300"
            onClick={handleQuickView}
            aria-label={`Quick view ${product.name}`}
          >
            <EyeIcon className="w-4 h-4" />
          </button>
        )}
      </div>

      <div className="product-card__content mt-4">
        <h3 className="product-card__title text-lg font-semibold text-gray-900 truncate">
          {product.name}
        </h3>

        <div className="product-card__price mt-2">
          {product.salePrice ? (
            <div className="flex items-center gap-2">
              <span className="text-lg font-bold text-red-600">
                ${product.salePrice.toFixed(2)}
              </span>
              <span className="text-sm text-gray-500 line-through">
                ${product.price.toFixed(2)}
              </span>
            </div>
          ) : (
            <span className="text-lg font-bold text-gray-900">
              ${product.price.toFixed(2)}
            </span>
          )}
        </div>

        <button
          type="button"
          className="product-card__add-to-cart w-full mt-4 bg-black text-white py-2 px-4 rounded-lg hover:bg-gray-800 transition-colors duration-300 disabled:opacity-50 disabled:cursor-not-allowed"
          onClick={handleAddToCart}
          disabled={isLoading || !product.inStock}
        >
          {isLoading ? 'Adding...' : 'Add to Cart'}
        </button>
      </div>
    </motion.article>
  );
};

export default ProductCard;
```

### 2. **Server vs Client Components** ✅

Use proper component directive and optimize for performance:

```typescript
// ✅ CORRECT - Server Component (default)
// No 'use client' directive needed
import { getProducts } from '@/lib/api/products';

export default async function ProductsPage() {
  const products = await getProducts();

  return (
    <div className="products-page">
      <h1>Our Products</h1>
      <ProductGrid products={products} />
    </div>
  );
}

// ✅ CORRECT - Client Component when needed
'use client';

import { useState, useEffect } from 'react';
import { useCart } from '@/context/CartContext';

export default function InteractiveComponent() {
  const [count, setCount] = useState(0);
  const { cartItems } = useCart();

  useEffect(() => {
    // Client-side effect
  }, []);

  return (
    <button onClick={() => setCount(count + 1)}>
      Count: {count}
    </button>
  );
}
```

### 3. **Component Naming** ✅

```typescript
// ✅ CORRECT - Descriptive, hierarchical naming
ProductCard.tsx
ProductGrid.tsx
ProductQuickView.tsx
ShoppingCartSidebar.tsx
UserAccountDropdown.tsx

// ❌ INCORRECT - Generic or unclear naming
Card.tsx
Grid.tsx
Modal.tsx
Dropdown.tsx
```

## State Management

### 1. **Context Providers** ✅

Use React Context for global state with proper organization:

```typescript
// ✅ CORRECT - Cart context with proper typing
'use client';

import React, { createContext, useContext, useReducer, ReactNode } from 'react';
import { Product, CartItem } from '@/type';

interface CartState {
  items: CartItem[];
  totalItems: number;
  totalPrice: number;
  isOpen: boolean;
}

interface CartContextType extends CartState {
  addToCart: (product: Product, quantity?: number) => void;
  removeFromCart: (productId: string) => void;
  updateQuantity: (productId: string, quantity: number) => void;
  clearCart: () => void;
  toggleCart: () => void;
}

const CartContext = createContext<CartContextType | undefined>(undefined);

type CartAction =
  | { type: 'ADD_TO_CART'; payload: { product: Product; quantity: number } }
  | { type: 'REMOVE_FROM_CART'; payload: { productId: string } }
  | { type: 'UPDATE_QUANTITY'; payload: { productId: string; quantity: number } }
  | { type: 'CLEAR_CART' }
  | { type: 'TOGGLE_CART' };

const cartReducer = (state: CartState, action: CartAction): CartState => {
  switch (action.type) {
    case 'ADD_TO_CART': {
      const { product, quantity } = action.payload;
      const existingItem = state.items.find(item => item.product.id === product.id);

      if (existingItem) {
        const updatedItems = state.items.map(item =>
          item.product.id === product.id
            ? { ...item, quantity: item.quantity + quantity }
            : item
        );
        return {
          ...state,
          items: updatedItems,
          totalItems: state.totalItems + quantity,
          totalPrice: state.totalPrice + (product.price * quantity)
        };
      }

      return {
        ...state,
        items: [...state.items, { product, quantity }],
        totalItems: state.totalItems + quantity,
        totalPrice: state.totalPrice + (product.price * quantity)
      };
    }

    case 'REMOVE_FROM_CART': {
      const { productId } = action.payload;
      const itemToRemove = state.items.find(item => item.product.id === productId);

      if (!itemToRemove) return state;

      return {
        ...state,
        items: state.items.filter(item => item.product.id !== productId),
        totalItems: state.totalItems - itemToRemove.quantity,
        totalPrice: state.totalPrice - (itemToRemove.product.price * itemToRemove.quantity)
      };
    }

    case 'TOGGLE_CART':
      return { ...state, isOpen: !state.isOpen };

    default:
      return state;
  }
};

const initialState: CartState = {
  items: [],
  totalItems: 0,
  totalPrice: 0,
  isOpen: false
};

export const CartProvider: React.FC<{ children: ReactNode }> = ({ children }) => {
  const [state, dispatch] = useReducer(cartReducer, initialState);

  const addToCart = (product: Product, quantity: number = 1) => {
    dispatch({ type: 'ADD_TO_CART', payload: { product, quantity } });
  };

  const removeFromCart = (productId: string) => {
    dispatch({ type: 'REMOVE_FROM_CART', payload: { productId } });
  };

  const updateQuantity = (productId: string, quantity: number) => {
    dispatch({ type: 'UPDATE_QUANTITY', payload: { productId, quantity } });
  };

  const clearCart = () => {
    dispatch({ type: 'CLEAR_CART' });
  };

  const toggleCart = () => {
    dispatch({ type: 'TOGGLE_CART' });
  };

  const value: CartContextType = {
    ...state,
    addToCart,
    removeFromCart,
    updateQuantity,
    clearCart,
    toggleCart
  };

  return (
    <CartContext.Provider value={value}>
      {children}
    </CartContext.Provider>
  );
};

export const useCart = (): CartContextType => {
  const context = useContext(CartContext);
  if (!context) {
    throw new Error('useCart must be used within a CartProvider');
  }
  return context;
};
```

### 2. **SWR for Data Fetching** ✅

Use SWR for efficient data fetching and caching:

```typescript
// ✅ CORRECT - Custom hook with SWR
import useSWR from 'swr';
import { Product } from '@/type/product';

const fetcher = async (url: string): Promise<Product[]> => {
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error('Failed to fetch products');
  }
  return response.json();
};

export const useProducts = (category?: string) => {
  const url = category ? `/api/products?category=${category}` : '/api/products';

  const { data, error, isLoading, mutate } = useSWR<Product[]>(url, fetcher, {
    revalidateOnFocus: false,
    revalidateOnReconnect: true,
    dedupingInterval: 60000, // 1 minute
  });

  return {
    products: data,
    isLoading,
    isError: error,
    refetch: mutate
  };
};

// Usage in component
const ProductList: React.FC = () => {
  const { products, isLoading, isError } = useProducts();

  if (isLoading) return <ProductsSkeleton />;
  if (isError) return <ErrorMessage />;

  return (
    <div className="grid grid-cols-1 md:grid-cols-3 lg:grid-cols-4 gap-6">
      {products?.map(product => (
        <ProductCard key={product.id} product={product} />
      ))}
    </div>
  );
};
```

## API Routes

### 1. **API Route Structure** ✅

```typescript
// ✅ CORRECT - src/app/api/products/route.ts
import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';

const QuerySchema = z.object({
  category: z.string().optional(),
  limit: z.coerce.number().min(1).max(100).default(20),
  page: z.coerce.number().min(1).default(1),
});

export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url);
    const query = QuerySchema.parse({
      category: searchParams.get('category'),
      limit: searchParams.get('limit'),
      page: searchParams.get('page'),
    });

    // Get domain from middleware header
    const domain = request.headers.get('x-domain') || 'default';

    const products = await getProductsForDomain(domain, query);

    return NextResponse.json({
      success: true,
      data: products,
      pagination: {
        page: query.page,
        limit: query.limit,
        total: products.length
      }
    });
  } catch (error) {
    console.error('Error fetching products:', error);

    if (error instanceof z.ZodError) {
      return NextResponse.json(
        { success: false, error: 'Invalid query parameters', details: error.errors },
        { status: 400 }
      );
    }

    return NextResponse.json(
      { success: false, error: 'Internal server error' },
      { status: 500 }
    );
  }
}

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const domain = request.headers.get('x-domain') || 'default';

    // Validate request body
    const product = await createProductForDomain(domain, body);

    return NextResponse.json({
      success: true,
      data: product
    }, { status: 201 });
  } catch (error) {
    console.error('Error creating product:', error);
    return NextResponse.json(
      { success: false, error: 'Failed to create product' },
      { status: 500 }
    );
  }
}
```

### 2. **Middleware** ✅

```typescript
// ✅ CORRECT - src/middleware.ts
import { NextRequest, NextResponse } from 'next/server';
import { getDomainConfig } from '@/lib/api/domains';

export function middleware(request: NextRequest) {
  const url = request.nextUrl;
  const hostname = request.headers.get('host') || '';

  // Extract domain from hostname
  const domain = extractDomainFromHostname(hostname);

  // Skip internal Next.js requests
  if (isInternalRequest(url.pathname)) {
    return NextResponse.next();
  }

  // Get domain configuration
  const domainConfig = getDomainConfig(domain);
  if (!domainConfig) {
    return new NextResponse('Domain not found', { status: 404 });
  }

  // Handle internationalization
  const { language, pathWithoutLanguage } = extractLanguageFromPath(url.pathname);

  // Rewrite to internal routing structure
  const newUrl = new URL(`/${domain}/${language}${pathWithoutLanguage}`, request.url);
  newUrl.search = url.search;

  // Add headers for downstream components
  const requestHeaders = new Headers(request.headers);
  requestHeaders.set('x-domain', domain);
  requestHeaders.set('x-language', language);
  requestHeaders.set('x-domain-config', JSON.stringify(domainConfig));

  return NextResponse.rewrite(newUrl, {
    request: { headers: requestHeaders }
  });
}

function extractDomainFromHostname(hostname: string): string {
  if (hostname.includes('.localhost:')) {
    return hostname.split('.')[0];
  }

  const parts = hostname.split('.');
  return parts.length > 2 ? parts[0] : 'default';
}

function isInternalRequest(pathname: string): boolean {
  return pathname.startsWith('/_next/') ||
         pathname.startsWith('/api/') ||
         pathname.startsWith('/images/') ||
         pathname.includes('.');
}

function extractLanguageFromPath(pathname: string): { language: string; pathWithoutLanguage: string } {
  const segments = pathname.split('/').filter(Boolean);
  const supportedLanguages = ['en', 'es', 'fr', 'de'];

  if (segments.length > 0 && supportedLanguages.includes(segments[0])) {
    return {
      language: segments[0],
      pathWithoutLanguage: '/' + segments.slice(1).join('/')
    };
  }

  return {
    language: 'en',
    pathWithoutLanguage: pathname
  };
}

export const config = {
  matcher: [
    '/((?!api|_next|_static|_vercel|favicon\\.ico|\\.[a-zA-Z]).*)',
  ],
};
```

## Styling Standards

### 1. **Tailwind CSS Usage** ✅

```typescript
// ✅ CORRECT - Utility-first with custom components
const ProductCard: React.FC = () => (
  <article className="group relative bg-white rounded-lg shadow-md overflow-hidden transition-transform duration-300 hover:scale-105">
    <div className="aspect-square overflow-hidden">
      <Image
        src={product.imageUrl}
        alt={product.name}
        className="w-full h-full object-cover group-hover:scale-110 transition-transform duration-500"
      />
    </div>

    <div className="p-4">
      <h3 className="text-lg font-semibold text-gray-900 mb-2 line-clamp-2">
        {product.name}
      </h3>

      <div className="flex items-center justify-between">
        <span className="text-xl font-bold text-primary">
          ${product.price}
        </span>

        <button className="btn-primary">
          Add to Cart
        </button>
      </div>
    </div>
  </article>
);
```

### 2. **CSS Modules for Complex Components** ✅

```scss
/* ✅ CORRECT - styles/components/ProductCard.module.scss */
.productCard {
  @apply relative bg-white rounded-lg shadow-md overflow-hidden;

  transition: transform 0.3s ease;

  &:hover {
    transform: translateY(-4px);

    .image {
      transform: scale(1.1);
    }
  }

  .image {
    @apply w-full h-full object-cover;
    transition: transform 0.5s ease;
  }

  .content {
    @apply p-4;

    .title {
      @apply text-lg font-semibold text-gray-900 mb-2;
      display: -webkit-box;
      -webkit-line-clamp: 2;
      -webkit-box-orient: vertical;
      overflow: hidden;
    }

    .price {
      @apply text-xl font-bold text-primary;
    }
  }
}
```

## TypeScript Standards

### 1. **Type Definitions** ✅

```typescript
// ✅ CORRECT - src/type/product.ts
export interface Product {
  id: string;
  name: string;
  slug: string;
  description: string;
  shortDescription?: string;
  price: number;
  salePrice?: number;
  imageUrl: string;
  images: string[];
  category: ProductCategory;
  brand: Brand;
  tags: string[];
  attributes: ProductAttribute[];
  variants: ProductVariant[];
  inventory: InventoryInfo;
  seo: SeoInfo;
  isActive: boolean;
  isFeatured: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface ProductCategory {
  id: string;
  name: string;
  slug: string;
  parentId?: string;
}

export interface ProductVariant {
  id: string;
  name: string;
  price: number;
  sku: string;
  inventory: number;
  attributes: Record<string, string>;
}

export interface CartItem {
  product: Product;
  variant?: ProductVariant;
  quantity: number;
  addedAt: string;
}

// API Response types
export interface ProductsResponse {
  success: boolean;
  data: Product[];
  pagination: {
    page: number;
    limit: number;
    total: number;
    totalPages: number;
  };
}

export interface ProductResponse {
  success: boolean;
  data: Product;
}
```

### 2. **Generic Components** ✅

```typescript
// ✅ CORRECT - Generic component with proper constraints
interface ListProps<T> {
  items: T[];
  renderItem: (item: T, index: number) => React.ReactNode;
  keyExtractor: (item: T) => string;
  className?: string;
  emptyMessage?: string;
}

function List<T>({
  items,
  renderItem,
  keyExtractor,
  className = '',
  emptyMessage = 'No items found'
}: ListProps<T>) {
  if (items.length === 0) {
    return (
      <div className={`text-center text-gray-500 py-8 ${className}`}>
        {emptyMessage}
      </div>
    );
  }

  return (
    <div className={className}>
      {items.map((item, index) => (
        <div key={keyExtractor(item)}>
          {renderItem(item, index)}
        </div>
      ))}
    </div>
  );
}

// Usage
<List
  items={products}
  renderItem={(product) => <ProductCard product={product} />}
  keyExtractor={(product) => product.id}
  className="grid grid-cols-1 md:grid-cols-3 gap-6"
  emptyMessage="No products available"
/>
```

## Performance Optimization

### 1. **Image Optimization** ✅

```typescript
// ✅ CORRECT - Optimized Image component usage
import Image from 'next/image';

const ProductImage: React.FC<{ product: Product }> = ({ product }) => (
  <div className="relative aspect-square">
    <Image
      src={product.imageUrl}
      alt={product.name}
      fill
      className="object-cover"
      sizes="(max-width: 768px) 100vw, (max-width: 1200px) 50vw, 33vw"
      priority={product.isFeatured}
      placeholder="blur"
      blurDataURL="data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD..."
    />
  </div>
);
```

### 2. **Lazy Loading** ✅

```typescript
// ✅ CORRECT - Dynamic imports for code splitting
import dynamic from 'next/dynamic';

const ProductQuickView = dynamic(
  () => import('@/components/ProductQuickView'),
  {
    loading: () => <QuickViewSkeleton />,
    ssr: false
  }
);

const LazyChart = dynamic(
  () => import('@/components/Chart'),
  {
    loading: () => <div>Loading chart...</div>,
    ssr: false
  }
);
```

### 3. **Memoization** ✅

```typescript
// ✅ CORRECT - React.memo for expensive components
import { memo } from 'react';

const ProductCard = memo<ProductCardProps>(({ product, onAddToCart }) => {
  // Component implementation
}, (prevProps, nextProps) => {
  // Custom comparison function
  return prevProps.product.id === nextProps.product.id &&
         prevProps.product.updatedAt === nextProps.product.updatedAt;
});

// ✅ CORRECT - useMemo for expensive calculations
const ExpensiveComponent: React.FC = () => {
  const expensiveValue = useMemo(() => {
    return products.reduce((total, product) => {
      return total + calculateComplexMetric(product);
    }, 0);
  }, [products]);

  return <div>{expensiveValue}</div>;
};
```

## Testing Standards

### 1. **Component Testing** ✅

```typescript
// ✅ CORRECT - Component test with Next.js utilities
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { useRouter } from 'next/navigation';
import ProductCard from '@/components/ProductCard';
import { CartProvider } from '@/context/CartContext';

// Mock Next.js router
jest.mock('next/navigation', () => ({
  useRouter: jest.fn(),
}));

const mockProduct = {
  id: '1',
  name: 'Test Product',
  price: 99.99,
  imageUrl: '/test-image.jpg',
  slug: 'test-product',
  inStock: true,
};

const renderWithProviders = (ui: React.ReactElement) => {
  return render(
    <CartProvider>
      {ui}
    </CartProvider>
  );
};

describe('ProductCard', () => {
  const mockPush = jest.fn();

  beforeEach(() => {
    (useRouter as jest.Mock).mockReturnValue({
      push: mockPush,
    });
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  it('renders product information correctly', () => {
    renderWithProviders(<ProductCard product={mockProduct} />);

    expect(screen.getByText('Test Product')).toBeInTheDocument();
    expect(screen.getByText('$99.99')).toBeInTheDocument();
    expect(screen.getByAltText('Test Product')).toBeInTheDocument();
  });

  it('adds product to cart when button is clicked', async () => {
    renderWithProviders(<ProductCard product={mockProduct} />);

    const addButton = screen.getByRole('button', { name: /add to cart/i });
    fireEvent.click(addButton);

    await waitFor(() => {
      expect(addButton).toHaveTextContent('Adding...');
    });
  });

  it('disables add to cart button when out of stock', () => {
    const outOfStockProduct = { ...mockProduct, inStock: false };
    renderWithProviders(<ProductCard product={outOfStockProduct} />);

    const addButton = screen.getByRole('button', { name: /add to cart/i });
    expect(addButton).toBeDisabled();
  });
});
```

## Error Handling

### 1. **Error Boundaries** ✅

```typescript
// ✅ CORRECT - Error boundary component
'use client';

import React, { Component, ErrorInfo, ReactNode } from 'react';

interface Props {
  children: ReactNode;
  fallback?: ReactNode;
}

interface State {
  hasError: boolean;
  error?: Error;
}

class ErrorBoundary extends Component<Props, State> {
  public state: State = {
    hasError: false,
  };

  public static getDerivedStateFromError(error: Error): State {
    return { hasError: true, error };
  }

  public componentDidCatch(error: Error, errorInfo: ErrorInfo) {
    console.error('ErrorBoundary caught an error:', error, errorInfo);

    // Send to error reporting service
    // reportError(error, errorInfo);
  }

  public render() {
    if (this.state.hasError) {
      if (this.props.fallback) {
        return this.props.fallback;
      }

      return (
        <div className="min-h-screen flex items-center justify-center bg-gray-50">
          <div className="text-center">
            <h2 className="text-2xl font-bold text-gray-900 mb-4">
              Something went wrong
            </h2>
            <p className="text-gray-600 mb-6">
              We're sorry, but something unexpected happened.
            </p>
            <button
              onClick={() => this.setState({ hasError: false })}
              className="bg-primary text-white px-6 py-2 rounded-lg hover:bg-primary-dark transition-colors"
            >
              Try again
            </button>
          </div>
        </div>
      );
    }

    return this.props.children;
  }
}

export default ErrorBoundary;
```

### 2. **Global Error Page** ✅

```typescript
// ✅ CORRECT - src/app/error.tsx
'use client';

import { useEffect } from 'react';

export default function Error({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useEffect(() => {
    console.error('Global error:', error);
    // Log to error reporting service
  }, [error]);

  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-50">
      <div className="text-center">
        <h2 className="text-2xl font-bold text-gray-900 mb-4">
          Something went wrong!
        </h2>
        <p className="text-gray-600 mb-6">
          {error.message || 'An unexpected error occurred'}
        </p>
        <button
          onClick={reset}
          className="bg-primary text-white px-6 py-2 rounded-lg hover:bg-primary-dark transition-colors"
        >
          Try again
        </button>
      </div>
    </div>
  );
}
```

## SEO and Meta Tags

### 1. **Dynamic Metadata** ✅

```typescript
// ✅ CORRECT - Dynamic metadata generation
import { Metadata } from 'next';
import { getProduct } from '@/lib/api/products';

interface Props {
  params: { slug: string; domain: string; lang: string };
}

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const product = await getProduct(params.slug, params.domain);

  if (!product) {
    return {
      title: 'Product Not Found',
      description: 'The requested product could not be found.',
    };
  }

  return {
    title: `${product.name} | Your Store`,
    description: product.shortDescription || product.description,
    keywords: product.tags.join(', '),
    openGraph: {
      title: product.name,
      description: product.shortDescription,
      images: [
        {
          url: product.imageUrl,
          width: 800,
          height: 800,
          alt: product.name,
        },
      ],
      type: 'product',
    },
    twitter: {
      card: 'summary_large_image',
      title: product.name,
      description: product.shortDescription,
      images: [product.imageUrl],
    },
    alternates: {
      canonical: `https://${params.domain}/products/${product.slug}`,
    },
  };
}

export default async function ProductPage({ params }: Props) {
  const product = await getProduct(params.slug, params.domain);

  if (!product) {
    return <ProductNotFound />;
  }

  return <ProductDetail product={product} />;
}
```

## Security Standards

### 1. **Input Validation** ✅

```typescript
// ✅ CORRECT - Zod schema validation
import { z } from 'zod';

const ContactFormSchema = z.object({
  name: z.string().min(2, 'Name must be at least 2 characters'),
  email: z.string().email('Invalid email address'),
  message: z.string().min(10, 'Message must be at least 10 characters'),
  honeypot: z.string().optional(), // Bot detection
});

export type ContactFormData = z.infer<typeof ContactFormSchema>;

// In API route
export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const validatedData = ContactFormSchema.parse(body);

    // Check honeypot
    if (validatedData.honeypot) {
      return NextResponse.json({ error: 'Bot detected' }, { status: 400 });
    }

    // Process form submission
    await processContactForm(validatedData);

    return NextResponse.json({ success: true });
  } catch (error) {
    if (error instanceof z.ZodError) {
      return NextResponse.json(
        { error: 'Validation failed', details: error.errors },
        { status: 400 }
      );
    }

    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
```

## Build and Deployment

### 1. **Environment Configuration** ✅

```typescript
// ✅ CORRECT - Environment variables
// .env.local
NEXT_PUBLIC_API_URL=https://api.oelite.com
NEXT_PUBLIC_SITE_URL=https://example.com
NEXT_PUBLIC_ANALYTICS_ID=GA_MEASUREMENT_ID

// Internal variables (not exposed to client)
DATABASE_URL=postgresql://...
API_SECRET_KEY=your-secret-key
WEBHOOK_SECRET=your-webhook-secret

// src/lib/env.ts
import { z } from 'zod';

const envSchema = z.object({
  NEXT_PUBLIC_API_URL: z.string().url(),
  NEXT_PUBLIC_SITE_URL: z.string().url(),
  DATABASE_URL: z.string(),
  API_SECRET_KEY: z.string(),
});

export const env = envSchema.parse(process.env);
```

### 2. **Build Configuration** ✅

```javascript
// ✅ CORRECT - next.config.js
/** @type {import('next').NextConfig} */
const nextConfig = {
  typescript: {
    tsconfigPath: './tsconfig.json',
  },

  images: {
    domains: ['example.com', 'cdn.example.com'],
    formats: ['image/webp', 'image/avif'],
    deviceSizes: [640, 750, 828, 1080, 1200, 1920, 2048, 3840],
    imageSizes: [16, 32, 48, 64, 96, 128, 256, 384],
  },

  experimental: {
    optimizeCss: true,
  },

  async headers() {
    return [
      {
        source: '/(.*)',
        headers: [
          {
            key: 'X-Frame-Options',
            value: 'DENY',
          },
          {
            key: 'X-Content-Type-Options',
            value: 'nosniff',
          },
          {
            key: 'Referrer-Policy',
            value: 'origin-when-cross-origin',
          },
        ],
      },
    ];
  },

  async redirects() {
    return [
      {
        source: '/old-page',
        destination: '/new-page',
        permanent: true,
      },
    ];
  },
};

module.exports = nextConfig;
```

## Common Anti-Patterns to Avoid

### 1. **Improper Server/Client Usage** ❌

```typescript
// ❌ FORBIDDEN - Server component with client-only features
export default async function BadComponent() {
  const [state, setState] = useState(); // Error: useState in server component

  useEffect(() => {
    // Error: useEffect in server component
  }, []);

  return <div>Bad component</div>;
}

// ❌ FORBIDDEN - Client component with server-only features
'use client';
export default async function AnotherBadComponent() {
  const data = await fetch('/api/data'); // Error: async in client component
  return <div>{data}</div>;
}
```

### 2. **Improper Image Usage** ❌

```typescript
// ❌ FORBIDDEN - Regular img tag instead of Next.js Image
<img src="/product.jpg" alt="Product" />

// ❌ FORBIDDEN - Missing optimization attributes
<Image src="/product.jpg" alt="Product" width={300} height={300} />

// ✅ CORRECT - Properly optimized
<Image
  src="/product.jpg"
  alt="Product"
  width={300}
  height={300}
  priority={isAboveFold}
  placeholder="blur"
  blurDataURL="..."
/>
```

## Validation Rules

### 1. **Compilation Checks**
- All pages must use App Router structure
- Components must properly declare 'use client' when needed
- TypeScript strict mode must be enabled
- No ESLint errors or warnings

### 2. **Runtime Checks**
- No hydration mismatches
- Proper error boundaries for all major features
- Accessibility compliance (WCAG 2.1 AA)
- Performance metrics within acceptable ranges

### 3. **Code Quality Checks**
- TypeScript coverage above 95%
- Test coverage above 80%
- Bundle size analysis for optimization
- Proper SEO meta tags on all pages

---

**Next Steps**: Review existing Next.js components and migrate any patterns that don't follow these standards. Implement ESLint rules and custom hooks to enforce these patterns automatically.