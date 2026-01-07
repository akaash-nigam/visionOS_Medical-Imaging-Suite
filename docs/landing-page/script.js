// Medical Imaging Suite - Landing Page JavaScript

// ==================== Mobile Menu Toggle ====================
document.addEventListener('DOMContentLoaded', () => {
    const mobileMenuToggle = document.querySelector('.mobile-menu-toggle');
    const navMenu = document.querySelector('.nav-menu');
    const navLinks = document.querySelectorAll('.nav-link');

    // Toggle mobile menu
    if (mobileMenuToggle) {
        mobileMenuToggle.addEventListener('click', () => {
            navMenu.classList.toggle('active');

            // Animate icon (hamburger to X)
            if (navMenu.classList.contains('active')) {
                mobileMenuToggle.innerHTML = '✕';
            } else {
                mobileMenuToggle.innerHTML = '☰';
            }
        });
    }

    // Close mobile menu when clicking nav links
    navLinks.forEach(link => {
        link.addEventListener('click', () => {
            navMenu.classList.remove('active');
            if (mobileMenuToggle) {
                mobileMenuToggle.innerHTML = '☰';
            }
        });
    });

    // Close mobile menu when clicking outside
    document.addEventListener('click', (e) => {
        if (!navMenu.contains(e.target) && !mobileMenuToggle.contains(e.target)) {
            navMenu.classList.remove('active');
            if (mobileMenuToggle) {
                mobileMenuToggle.innerHTML = '☰';
            }
        }
    });
});

// ==================== Navbar Scroll Effect ====================
window.addEventListener('scroll', () => {
    const navbar = document.querySelector('.navbar');

    if (window.scrollY > 50) {
        navbar.classList.add('scrolled');
    } else {
        navbar.classList.remove('scrolled');
    }
});

// ==================== Smooth Scroll for Anchor Links ====================
document.querySelectorAll('a[href^="#"]').forEach(anchor => {
    anchor.addEventListener('click', function (e) {
        e.preventDefault();

        const target = document.querySelector(this.getAttribute('href'));

        if (target) {
            const navbarHeight = document.querySelector('.navbar').offsetHeight;
            const targetPosition = target.getBoundingClientRect().top + window.pageYOffset - navbarHeight;

            window.scrollTo({
                top: targetPosition,
                behavior: 'smooth'
            });
        }
    });
});

// ==================== Animated Counter for Stats ====================
const animateCounter = (element, start, end, duration) => {
    const range = end - start;
    const increment = range / (duration / 16); // 60fps
    let current = start;

    const timer = setInterval(() => {
        current += increment;

        if ((increment > 0 && current >= end) || (increment < 0 && current <= end)) {
            current = end;
            clearInterval(timer);
        }

        // Format number with commas
        const formatted = Math.floor(current).toLocaleString();
        element.textContent = formatted;
    }, 16);
};

// Trigger counter animation when stats section is visible
const observeStats = () => {
    const stats = document.querySelectorAll('.stat-number');

    const observer = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting && !entry.target.dataset.animated) {
                const text = entry.target.textContent.trim();

                // Parse different formats
                if (text.includes('×')) {
                    // Handle "512×512×300" format
                    entry.target.dataset.animated = 'true';
                } else if (text.includes('s')) {
                    // Handle "<3s" format - animate from 0 to 3
                    const num = parseInt(text.replace(/[^0-9]/g, ''));
                    animateCounter(entry.target, 0, num, 1000);
                    setTimeout(() => {
                        entry.target.textContent = `<${num}s`;
                    }, 1000);
                    entry.target.dataset.animated = 'true';
                } else if (text.includes('%')) {
                    // Handle "85%" format
                    const num = parseInt(text.replace('%', ''));
                    animateCounter(entry.target, 0, num, 1500);
                    setTimeout(() => {
                        entry.target.textContent = `${num}%`;
                    }, 1500);
                    entry.target.dataset.animated = 'true';
                }
            }
        });
    }, { threshold: 0.5 });

    stats.forEach(stat => observer.observe(stat));
};

// ==================== Intersection Observer for Fade-in Animations ====================
const observeFadeIn = () => {
    const fadeElements = document.querySelectorAll('.feature-card, .benefit-item, .tech-card, .pricing-card');

    const observer = new IntersectionObserver((entries) => {
        entries.forEach((entry, index) => {
            if (entry.isIntersecting) {
                // Add stagger delay
                setTimeout(() => {
                    entry.target.classList.add('fade-in', 'visible');
                }, index * 100);
            }
        });
    }, {
        threshold: 0.1,
        rootMargin: '0px 0px -50px 0px'
    });

    fadeElements.forEach(element => {
        element.classList.add('fade-in');
        observer.observe(element);
    });
};

// ==================== Form Validation and Submission ====================
const handleFormSubmission = () => {
    const form = document.getElementById('demo-form');

    if (form) {
        form.addEventListener('submit', async (e) => {
            e.preventDefault();

            const submitButton = form.querySelector('.form-submit');
            const originalText = submitButton.textContent;

            // Get form data
            const formData = {
                name: document.getElementById('name').value,
                email: document.getElementById('email').value,
                practice: document.getElementById('practice').value
            };

            // Basic validation
            if (!formData.name || !formData.email || !formData.practice) {
                showNotification('Please fill in all fields', 'error');
                return;
            }

            // Email validation
            const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
            if (!emailRegex.test(formData.email)) {
                showNotification('Please enter a valid email address', 'error');
                return;
            }

            // Show loading state
            submitButton.disabled = true;
            submitButton.textContent = 'Submitting...';

            // Simulate API call (replace with actual endpoint)
            try {
                await new Promise(resolve => setTimeout(resolve, 1500));

                // Success
                showNotification('Thank you! We\'ll contact you soon for a demo.', 'success');
                form.reset();

            } catch (error) {
                showNotification('Something went wrong. Please try again.', 'error');
            } finally {
                submitButton.disabled = false;
                submitButton.textContent = originalText;
            }
        });
    }
};

// ==================== Notification System ====================
const showNotification = (message, type = 'info') => {
    // Remove existing notification
    const existingNotification = document.querySelector('.notification');
    if (existingNotification) {
        existingNotification.remove();
    }

    // Create notification element
    const notification = document.createElement('div');
    notification.className = `notification notification-${type}`;
    notification.textContent = message;

    // Style notification
    Object.assign(notification.style, {
        position: 'fixed',
        top: '100px',
        right: '20px',
        padding: '1rem 1.5rem',
        borderRadius: '8px',
        backgroundColor: type === 'success' ? '#00C7B1' : type === 'error' ? '#E63946' : '#0066CC',
        color: '#FFFFFF',
        fontWeight: '600',
        boxShadow: '0 4px 16px rgba(0, 0, 0, 0.2)',
        zIndex: '9999',
        animation: 'slideInRight 0.3s ease',
        maxWidth: '400px'
    });

    // Add to DOM
    document.body.appendChild(notification);

    // Remove after 5 seconds
    setTimeout(() => {
        notification.style.animation = 'slideOutRight 0.3s ease';
        setTimeout(() => notification.remove(), 300);
    }, 5000);
};

// Add notification animations to CSS dynamically
const addNotificationStyles = () => {
    const style = document.createElement('style');
    style.textContent = `
        @keyframes slideInRight {
            from {
                transform: translateX(400px);
                opacity: 0;
            }
            to {
                transform: translateX(0);
                opacity: 1;
            }
        }

        @keyframes slideOutRight {
            from {
                transform: translateX(0);
                opacity: 1;
            }
            to {
                transform: translateX(400px);
                opacity: 0;
            }
        }
    `;
    document.head.appendChild(style);
};

// ==================== Pricing Card Selection ====================
const handlePricingSelection = () => {
    const pricingCards = document.querySelectorAll('.pricing-card');

    pricingCards.forEach(card => {
        const button = card.querySelector('.pricing-cta');

        if (button) {
            button.addEventListener('click', () => {
                const plan = card.querySelector('.pricing-title').textContent;

                // Scroll to CTA form
                const ctaSection = document.getElementById('demo');
                if (ctaSection) {
                    ctaSection.scrollIntoView({ behavior: 'smooth' });

                    // Pre-fill practice name with plan selection
                    setTimeout(() => {
                        const practiceInput = document.getElementById('practice');
                        if (practiceInput && !practiceInput.value) {
                            practiceInput.placeholder = `Interested in ${plan}`;
                        }
                    }, 500);
                }
            });
        }
    });
};

// ==================== Keyboard Navigation ====================
const handleKeyboardNavigation = () => {
    // Escape key to close mobile menu
    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape') {
            const navMenu = document.querySelector('.nav-menu');
            const mobileMenuToggle = document.querySelector('.mobile-menu-toggle');

            if (navMenu.classList.contains('active')) {
                navMenu.classList.remove('active');
                if (mobileMenuToggle) {
                    mobileMenuToggle.innerHTML = '☰';
                }
            }
        }
    });
};

// ==================== Parallax Effect for Hero ====================
const addParallaxEffect = () => {
    const hero = document.querySelector('.hero');

    if (hero) {
        window.addEventListener('scroll', () => {
            const scrolled = window.pageYOffset;
            const parallaxSpeed = 0.5;

            hero.style.transform = `translateY(${scrolled * parallaxSpeed}px)`;
        });
    }
};

// ==================== Loading Animation ====================
const hideLoader = () => {
    const loader = document.getElementById('loader');
    if (loader) {
        setTimeout(() => {
            loader.style.opacity = '0';
            setTimeout(() => {
                loader.style.display = 'none';
            }, 300);
        }, 500);
    }
};

// ==================== Initialize All Features ====================
const init = () => {
    // Add notification styles
    addNotificationStyles();

    // Initialize observers
    observeStats();
    observeFadeIn();

    // Initialize form handling
    handleFormSubmission();

    // Initialize pricing interactions
    handlePricingSelection();

    // Initialize keyboard navigation
    handleKeyboardNavigation();

    // Add parallax effect (optional - can be disabled for performance)
    // addParallaxEffect();

    // Hide loader if present
    hideLoader();

    console.log('Medical Imaging Suite landing page initialized');
};

// ==================== Run on DOM Load ====================
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
} else {
    init();
}

// ==================== Performance Monitoring (Development) ====================
if ('performance' in window) {
    window.addEventListener('load', () => {
        const perfData = performance.getEntriesByType('navigation')[0];
        console.log(`Page load time: ${perfData.loadEventEnd - perfData.fetchStart}ms`);
    });
}

// ==================== Service Worker Registration (Optional) ====================
// Uncomment to enable PWA features
/*
if ('serviceWorker' in navigator) {
    window.addEventListener('load', () => {
        navigator.serviceWorker.register('/sw.js')
            .then(registration => console.log('SW registered:', registration))
            .catch(error => console.log('SW registration failed:', error));
    });
}
*/
