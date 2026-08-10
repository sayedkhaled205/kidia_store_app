(function () {
	'use strict';

	const segmentStorageKey = 'mobishop_ai_offer_segment_v1';

	function list(root, selector) {
		return Array.from(root.querySelectorAll(selector));
	}

	function csv(value) {
		return String(value || '')
			.split(',')
			.map(function (item) { return item.trim(); })
			.filter(Boolean);
	}

	function savedSegment() {
		try {
			return window.sessionStorage.getItem(segmentStorageKey) || '';
		} catch (_error) {
			return '';
		}
	}

	function rememberSegment(segment) {
		try {
			window.sessionStorage.setItem(segmentStorageKey, segment);
		} catch (_error) {
			// A blocked storage API must not stop the workspace controls.
		}
	}

	function activeSegment(page) {
		const active = page.querySelector('[data-ai-segment-tab].is-active');
		return active ? String(active.dataset.aiSegmentTab || '') : '';
	}

	function activePlaybook(page) {
		return page.querySelector('[data-ai-playbook-schemes].is-active');
	}

	function syncDecisionVisibility(page) {
		const segment = activeSegment(page);
		const playbook = activePlaybook(page);
		const schemes = playbook ? csv(playbook.dataset.aiPlaybookSchemes) : [];
		const kinds = playbook ? csv(playbook.dataset.aiPlaybookKind) : [];
		let visibleCards = 0;

		list(page, '[data-ai-segment-panel]').forEach(function (panel) {
			const isCurrent = panel.dataset.aiSegmentPanel === segment;
			panel.hidden = !isCurrent;
			if (!isCurrent) return;

			list(panel, '[data-ai-decision-scheme]').forEach(function (card) {
				const scheme = String(card.dataset.aiDecisionScheme || '');
				const kind = String(card.dataset.aiDecisionKind || '');
				const matches = !playbook ||
					(schemes.length ? schemes.includes(scheme) : (!kinds.length || kinds.includes('all') || kinds.includes(kind)));
				card.hidden = !matches;
				if (matches) visibleCards += 1;
			});

			list(panel, '[data-ai-idea-group]').forEach(function (group) {
				group.hidden = !group.querySelector('[data-ai-decision-scheme]:not([hidden])');
			});

			const empty = panel.querySelector('[data-ai-playbook-empty]');
			if (empty) empty.hidden = !playbook || visibleCards > 0;
		});

		const status = page.querySelector('[data-ai-filter-status]');
		const segmentButton = page.querySelector('[data-ai-segment-tab].is-active');
		if (status && segmentButton) {
			const segmentLabel = (segmentButton.querySelector('span') || segmentButton).textContent.trim();
			const playbookLabel = playbook ? playbook.textContent.trim() : '';
			status.textContent = playbook
				? visibleCards + ' matching ideas in ' + segmentLabel + ' for “' + playbookLabel + '”.'
				: 'Showing ' + segmentLabel + ' only. Choose a playbook to filter its organized idea categories.';
		}
	}

	function selectSegment(page, requested, shouldRemember) {
		const tabs = list(page, '[data-ai-segment-tab]');
		if (!tabs.length) return;
		const selected = tabs.find(function (tab) {
			return tab.dataset.aiSegmentTab === requested;
		}) || tabs[0];

		tabs.forEach(function (tab) {
			const isSelected = tab === selected;
			tab.classList.toggle('is-active', isSelected);
			tab.setAttribute('aria-selected', isSelected ? 'true' : 'false');
			tab.tabIndex = isSelected ? 0 : -1;
		});
		if (shouldRemember) rememberSegment(String(selected.dataset.aiSegmentTab || ''));
		syncDecisionVisibility(page);
	}

	function selectWorkspace(page, target) {
		list(page, '[data-ai-workspace-tab]').forEach(function (tab) {
			const isSelected = tab.dataset.aiWorkspaceTab === target;
			tab.classList.toggle('is-active', isSelected);
			tab.setAttribute('aria-selected', isSelected ? 'true' : 'false');
		});
		list(page, '[data-ai-workspace-panel]').forEach(function (panel) {
			panel.hidden = panel.dataset.aiWorkspacePanel !== target;
		});
	}

	function togglePlaybook(page, button) {
		const wasActive = button.classList.contains('is-active');
		list(page, '[data-ai-playbook-schemes]').forEach(function (item) {
			item.classList.remove('is-active');
			item.setAttribute('aria-pressed', 'false');
		});
		if (!wasActive) {
			button.classList.add('is-active');
			button.setAttribute('aria-pressed', 'true');
			const schemes = csv(button.dataset.aiPlaybookSchemes);
			const currentPanel = page.querySelector('[data-ai-segment-panel="' + activeSegment(page) + '"]');
			const currentHasMatch = currentPanel && list(currentPanel, '[data-ai-decision-scheme]').some(function (card) {
				return schemes.includes(String(card.dataset.aiDecisionScheme || ''));
			});
			if (schemes.length && !currentHasMatch) {
				const matchingPanel = list(page, '[data-ai-segment-panel]').find(function (panel) {
					return list(panel, '[data-ai-decision-scheme]').some(function (card) {
						return schemes.includes(String(card.dataset.aiDecisionScheme || ''));
					});
				});
				if (matchingPanel) {
					selectSegment(page, String(matchingPanel.dataset.aiSegmentPanel || ''), true);
					return;
				}
			}
		}
		syncDecisionVisibility(page);
	}

	function bindPage(page) {
		if (!page || page.dataset.aiOfferWorkspaceBound === '1') return;
		page.dataset.aiOfferWorkspaceBound = '1';

		page.addEventListener('click', function (event) {
			const workspaceTab = event.target.closest('[data-ai-workspace-tab]');
			if (workspaceTab && page.contains(workspaceTab)) {
				selectWorkspace(page, String(workspaceTab.dataset.aiWorkspaceTab || 'decisions'));
				return;
			}

			const segmentTab = event.target.closest('[data-ai-segment-tab]');
			if (segmentTab && page.contains(segmentTab)) {
				selectSegment(page, String(segmentTab.dataset.aiSegmentTab || ''), true);
				return;
			}

			const playbook = event.target.closest('[data-ai-playbook-schemes]');
			if (playbook && page.contains(playbook)) {
				togglePlaybook(page, playbook);
			}
		});

		page.addEventListener('keydown', function (event) {
			const current = event.target.closest('[data-ai-segment-tab]');
			if (!current || !['ArrowLeft', 'ArrowRight', 'Home', 'End'].includes(event.key)) return;
			const tabs = list(page, '[data-ai-segment-tab]');
			let index = tabs.indexOf(current);
			if ('Home' === event.key) index = 0;
			if ('End' === event.key) index = tabs.length - 1;
			if ('ArrowLeft' === event.key) index = (index - 1 + tabs.length) % tabs.length;
			if ('ArrowRight' === event.key) index = (index + 1) % tabs.length;
			event.preventDefault();
			tabs[index].focus();
			selectSegment(page, String(tabs[index].dataset.aiSegmentTab || ''), true);
		});

		const initialWorkspace = page.querySelector('[data-ai-workspace-tab].is-active');
		if (initialWorkspace) {
			selectWorkspace(page, String(initialWorkspace.dataset.aiWorkspaceTab || 'decisions'));
		}
		selectSegment(page, savedSegment() || activeSegment(page) || 'fast', false);
	}

	function initialize(root) {
		const pages = [];
		if (root && root.matches && root.matches('.mobishop-ai-page')) pages.push(root);
		list(root || document, '.mobishop-ai-page').forEach(function (page) {
			if (!pages.includes(page)) pages.push(page);
		});
		pages.forEach(bindPage);
	}

	document.addEventListener('mobishop:cms-page-ready', function () {
		initialize(document);
	});

	if ('loading' === document.readyState) {
		document.addEventListener('DOMContentLoaded', function () { initialize(document); }, { once: true });
	} else {
		initialize(document);
	}
})();
