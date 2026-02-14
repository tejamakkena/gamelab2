// Theme Toggle System with localStorage persistence
// Supports light mode, dark mode (default), and auto (system preference)

(function() {
    'use strict';
    
    const THEME_KEY = 'gamelab-theme';
    const THEME_CLASS_LIGHT = 'theme-light';
    
    // Initialize theme on page load
    function initTheme() {
        const savedTheme = localStorage.getItem(THEME_KEY) || 'dark';
        applyTheme(savedTheme);
    }
    
    // Apply theme to document
    function applyTheme(theme) {
        const html = document.documentElement;
        
        if (theme === 'light') {
            html.classList.add(THEME_CLASS_LIGHT);
        } else {
            html.classList.remove(THEME_CLASS_LIGHT);
        }
        
        // Update toggle button if it exists
        updateToggleButton(theme);
    }
    
    // Toggle between light and dark
    function toggleTheme() {
        const html = document.documentElement;
        const isLight = html.classList.contains(THEME_CLASS_LIGHT);
        const newTheme = isLight ? 'dark' : 'light';
        
        localStorage.setItem(THEME_KEY, newTheme);
        applyTheme(newTheme);
        
        // Add animation class for smooth transition
        html.classList.add('theme-transitioning');
        setTimeout(() => html.classList.remove('theme-transitioning'), 300);
    }
    
    // Update toggle button appearance
    function updateToggleButton(theme) {
        const button = document.getElementById('theme-toggle');
        if (!button) return;
        
        const icon = button.querySelector('.theme-icon');
        if (!icon) return;
        
        if (theme === 'light') {
            icon.textContent = '🌙';
            button.setAttribute('aria-label', 'Switch to dark mode');
        } else {
            icon.textContent = '☀️';
            button.setAttribute('aria-label', 'Switch to light mode');
        }
    }
    
    // Create and inject theme toggle button
    function createToggleButton() {
        const button = document.createElement('button');
        button.id = 'theme-toggle';
        button.className = 'theme-toggle-btn';
        button.setAttribute('aria-label', 'Toggle theme');
        button.innerHTML = '<span class="theme-icon">☀️</span>';
        
        button.addEventListener('click', toggleTheme);
        
        // Inject into body
        document.body.appendChild(button);
        
        // Update initial state
        const savedTheme = localStorage.getItem(THEME_KEY) || 'dark';
        updateToggleButton(savedTheme);
    }
    
    // Initialize on DOM ready
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', () => {
            initTheme();
            createToggleButton();
        });
    } else {
        initTheme();
        createToggleButton();
    }
    
    // Expose toggle function globally for manual triggers
    window.toggleTheme = toggleTheme;
})();
